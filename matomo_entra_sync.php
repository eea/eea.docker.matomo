<?php

// === Validate and Load Environment Variables ===
function requireEnv(string $key, bool $allowEmpty = false): string {
    $value = getenv($key);
    if ($value === false || (!$allowEmpty && trim($value) === '')) {
        die("Missing required environment variable: $key\n");
    }
    return $value;
}

// === Load Environment Variables ===
$tenantId = requireEnv('AZURE_TENANT_ID');
$clientId = requireEnv('AZURE_CLIENT_ID');
$clientSecret = requireEnv('AZURE_CLIENT_SECRET');
$viewGroupName = requireEnv('AZURE_VIEW_GROUP');

$dbConfig = [
    'host' => requireEnv('MATOMO_DATABASE_HOST'),
    'user' => requireEnv('MATOMO_DATABASE_USERNAME'),
    'pass' => requireEnv('MATOMO_DATABASE_PASSWORD'),
    'name' => requireEnv('MATOMO_DATABASE_DBNAME'),
    'port' => getenv('MATOMO_DATABASE_PORT') ?: '3306'
];

// === Microsoft Graph: Get Access Token ===
function getAccessToken($tenantId, $clientId, $clientSecret): string {
    $url = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token";
    $data = http_build_query([
        'grant_type' => 'client_credentials',
        'client_id' => $clientId,
        'client_secret' => $clientSecret,
        'scope' => 'https://graph.microsoft.com/.default'
    ]);

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $data
    ]);
    $response = curl_exec($ch);
    curl_close($ch);

    $json = json_decode($response, true);
    return $json['access_token'] ?? '';
}

// === Get Group ID by Display Name ===
function getGroupId(string $token, string $groupName): ?string {
    $url = "https://graph.microsoft.com/v1.0/groups?\$filter=" . urlencode("displayName eq '$groupName'");
    $headers = ["Authorization: Bearer $token"];

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => $headers
    ]);
    $response = curl_exec($ch);
    curl_close($ch);

    if ($response === false) {
        die("cURL error: " . curl_error($ch));
    }

    $data = json_decode($response, true);

    return $data['value'][0]['id'] ?? null;
}

// === Get Members of the Group ===
function getGroupMembers(string $groupId, string $token): array {
    $members = [];
    $url = "https://graph.microsoft.com/v1.0/groups/$groupId/members?\$select=mail,userPrincipalName,id";
    $headers = ["Authorization: Bearer $token"];

    while ($url) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $headers
        ]);
        $response = curl_exec($ch);
        curl_close($ch);

        $data = json_decode($response, true);
        foreach ($data['value'] ?? [] as $user) {
            if (($user['@odata.type'] ?? '') === '#microsoft.graph.group') {
                // Recursively get members of nested group
                $members = array_merge($members, getGroupMembers($user['id'], $token));
            } else {
                $email = strtolower($user['mail'] ?? $user['userPrincipalName'] ?? '');
                if ($email) {
                    $members[] = $email;
                }
            }
        }

        $url = $data['@odata.nextLink'] ?? null;
    }

    return $members;
}

// === Create Missing Matomo Users ===
function createMissingMatomoUsers(array $emails, array $dbConfig): void {
    $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['name']}";
    $pdo = new PDO($dsn, $dbConfig['user'], $dbConfig['pass']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $placeholders = implode(',', array_fill(0, count($emails), '?'));
    $stmt = $pdo->prepare("SELECT LOWER(email) as email FROM matomo_user WHERE LOWER(email) IN ($placeholders)");
    $stmt->execute($emails);
    $existingEmails = array_column($stmt->fetchAll(), 'email');

    $newUsers = array_diff($emails, $existingEmails);
    $inserted = 0;

    $stmt = $pdo->prepare("INSERT INTO matomo_user (login, password, email, superuser_access, date_registered) VALUES (?, ?, ?, 0, NOW())");
    foreach ($newUsers as $email) {
        $login = $email;
        $password = '1234';  // You should hash this in production
        $stmt->execute([$login, $password, $email]);
        echo "Created new Matomo user: $email\n";
        $inserted++;
    }

    echo "$inserted user(s) created in matomo_user.\n";
}

// === Sync Users to Matomo DB ===
function syncToMatomoDB(array $emails, array $dbConfig): void {
    $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['name']}";
    $pdo = new PDO($dsn, $dbConfig['user'], $dbConfig['pass']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $placeholders = implode(',', array_fill(0, count($emails), '?'));
    $stmt = $pdo->prepare("SELECT login, LOWER(email) as email FROM matomo_user WHERE LOWER(email) IN ($placeholders)");
    $stmt->execute($emails);
    $users = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $users[$row['email']] = $row['login'];
    }

    $siteStmt = $pdo->query("SELECT idsite FROM matomo_site");
    $siteIds = $siteStmt->fetchAll(PDO::FETCH_COLUMN);

    $inserted = 0;
    $checkStmt = $pdo->prepare("SELECT 1 FROM matomo_access WHERE login = ? AND idsite = ?");
    $insertStmt = $pdo->prepare("INSERT INTO matomo_access (login, idsite, access) VALUES (?, ?, 'view')");

    foreach ($emails as $email) {
        $login = $users[$email] ?? null;
        if (!$login) {
            echo "Email $email not found in matomo_user  ^`^t skipping\n";
            continue;
        }

        foreach ($siteIds as $siteId) {
            $checkStmt->execute([$login, $siteId]);
            if (!$checkStmt->fetch()) {
                $insertStmt->execute([$login, $siteId]);
                echo "Granted 'view' to $login on site $siteId\n";
                $inserted++;
            }
        }
    }

    echo "\nSync complete. $inserted access records inserted.\n";
}

// === Main Logic ===
function main() {
    global $tenantId, $clientId, $clientSecret, $dbConfig, $viewGroupName;

    echo "Authenticating to Microsoft Graph...\n";
    $token = getAccessToken($tenantId, $clientId, $clientSecret);

    if (!$token) {
        echo "Failed to retrieve access token.\n";
        return;
    }

    echo "Fetching group ID for '$viewGroupName'...\n";
    $groupId = getGroupId($token, $viewGroupName);
    if (!$groupId) {
        echo "Group '$viewGroupName' not found in Entra ID.\n";
        return;
    }

    echo "Fetching group members...\n";
    $emails = getGroupMembers($groupId, $token);
    if (empty($emails)) {
        echo "No members found in '$viewGroupName'.\n";
        return;
    }

    echo "Checking for new users...\n";
    createMissingMatomoUsers($emails, $dbConfig);

    echo "Matching users to Matomo and syncing access for " . count($emails) . " emails...\n";
    syncToMatomoDB($emails, $dbConfig);
}

main();
