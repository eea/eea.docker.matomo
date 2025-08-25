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

$debugEnv = strtolower(getenv('SYNC_DEBUG') ?: 'false');
$debug = in_array($debugEnv, ['1', 'true', 'yes'], true);

// admin email to protect from deletion
$adminEmail = getenv('ADMIN_EMAIL') ?: null;

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

function getAllUsers(string $token): array {
    global $debug;

    $url = "https://graph.microsoft.com/v1.0/users";
    $headers = [
        "Authorization: Bearer $token",
        "Accept: application/json"
    ];

    $users = [];

    while ($url) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_RETURNTRANSFER => true
        ]);
        $response = curl_exec($ch);
        curl_close($ch);

        if (!$response) {
            break;
        }

        $data = json_decode($response, true);
        if (!isset($data['value'])) {
            break;
        }

        $pageUsers = $data['value'];

        foreach ($pageUsers as $user) {
            $displayName    = $user['displayName'] ?? 'N/A';
            $principalName  = $user['userPrincipalName'] ?? 'N/A';
            $email          = $user['mail'] ?? null;

            if (!empty($debug)) {
                print_r($user);
            }

            if ($email) {
                $users[] = $email;
            }
        }

        // Follow pagination if available
        $url = $data['@odata.nextLink'] ?? null;
    }

    return $users;
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
                $email = $user['mail'] ?? $user['userPrincipalName'] ?? '';
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
function createMissingMatomoUsers(array $emails, array $dbConfig, bool $debug = false): void {
    $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['name']}";
    $pdo = new PDO($dsn, $dbConfig['user'], $dbConfig['pass']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $inserted = 0;
    $updated = 0;

    foreach ($emails as $email) {
        // Check if the user already exists (case-insensitive)
        $stmt = $pdo->prepare("SELECT email FROM matomo_user WHERE LOWER(email) = LOWER(?)");
        $stmt->execute([$email]);
        $existingEmail = $stmt->fetchColumn();

        if ($existingEmail === false) {
            // Insert new user
            $login = $email;
            $randomString = bin2hex(random_bytes(16));
            $password = password_hash($randomString, PASSWORD_BCRYPT);
            $stmt = $pdo->prepare("
                INSERT INTO matomo_user (login, password, email, superuser_access, date_registered)
                VALUES (?, ?, ?, 0, NOW())
            ");
            $stmt->execute([$login, $password, $email]);
            echo "Created new Matomo user: $email\n";
            $inserted++;
        } else {
            if ($existingEmail !== $email) {
                // Update case difference
                $stmt = $pdo->prepare("UPDATE matomo_user SET email = ? WHERE LOWER(email) = LOWER(?)");
                $stmt->execute([$email, $email]);
                echo "Updated email case: $existingEmail -> $email\n";
                $updated++;
            } else {
                if ($debug) {
                    echo "User already exists: $email\n";
                }
            }
        }
    }

    echo "$inserted user(s) created, $updated user(s) updated in matomo_user.\n";
}



function grantAccessToAll(array $emails, array $dbConfig): void {
    $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['name']}";
    $pdo = new PDO($dsn, $dbConfig['user'], $dbConfig['pass']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Get all site IDs once
    $siteStmt = $pdo->query("SELECT idsite FROM matomo_site");
    $siteIds = $siteStmt->fetchAll(PDO::FETCH_COLUMN);

    $inserted = 0;

    $userStmt = $pdo->prepare("SELECT login, email FROM matomo_user WHERE LOWER(email) = LOWER(?)");
    $checkStmt = $pdo->prepare("SELECT 1 FROM matomo_access WHERE login = ? AND idsite = ?");
    $insertStmt = $pdo->prepare("INSERT INTO matomo_access (login, idsite, access) VALUES (?, ?, 'view')");

    foreach ($emails as $email) {
        // Lookup user by email (case-insensitive)
        $userStmt->execute([$email]);
        $row = $userStmt->fetch(PDO::FETCH_ASSOC);

        if (!$row) {
            echo "Warn: Email $email not found in matomo_user — skipping\n";
            continue;
        }

        $login = $row['login'];

        // Grant access for each site if not already present
        foreach ($siteIds as $siteId) {
            $checkStmt->execute([$login, $siteId]);
            if (!$checkStmt->fetch()) {
                $insertStmt->execute([$login, $siteId]);
                $inserted++;
                echo "Granted 'view' to $login on site $siteId\n";
            }
        }
    }

    echo "\nSync complete. $inserted access records inserted.\n";
}

function deleteMissingMatomoUsers(array $allowedEmails, array $dbConfig): void {
    $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['name']}";
    $pdo = new PDO($dsn, $dbConfig['user'], $dbConfig['pass']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Normalize allowed emails to lowercase for comparison
    $allowedLower = array_map('strtolower', $allowedEmails);

    $deletedCount = 0;

    // Fetch all users in Matomo, including superuser flag
    $stmt = $pdo->query("SELECT login, email, superuser_access FROM matomo_user");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($users as $user) {
        $email = $user['email'];
        $login = $user['login'];
        $isSuperuser = (int)$user['superuser_access'] === 1;

        if (!in_array(strtolower($email), $allowedLower, true)) {
            if ($isSuperuser) {
                echo "Skipping superuser: $email (login=$login)\n";
                continue;
            }

            // Fetch existing access records before deletion
            $accessStmt = $pdo->prepare("SELECT idsite, access FROM matomo_access WHERE login = ?");
            $accessStmt->execute([$login]);
            $accessRecords = $accessStmt->fetchAll(PDO::FETCH_ASSOC);

            if ($accessRecords) {
                $siteIds = implode(", ", array_column($accessRecords, 'idsite'));
                echo "Logging access for $email before deletion: Site IDs: $siteIds\n";
            }

            // Delete related access records first
            $delAccessStmt = $pdo->prepare("DELETE FROM matomo_access WHERE login = ?");
            $delAccessStmt->execute([$login]);

            // Delete user itself
            $delUserStmt = $pdo->prepare("DELETE FROM matomo_user WHERE login = ?");
            $delUserStmt->execute([$login]);

            $deletedCount++;
            echo "Deleted Matomo user: $email (login=$login)\n";
        }
    }

    echo "\nCleanup complete. $deletedCount user(s) deleted from matomo_user.\n";
}

function getGroupList(string $token): ?string
{
    global $debug;

    $url = "https://graph.microsoft.com/v1.0/groups";
    $headers = [
        "Authorization: Bearer $token",
        "Accept: application/json"
    ];

    $groups = [];

    while ($url) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_RETURNTRANSFER => true
        ]);
        $response = curl_exec($ch);
        curl_close($ch);

        if (!$response) {
            break;
        }

        $data = json_decode($response, true);
        if (!isset($data['value'])) {
            break;
        }

        $pageGroups = $data['value'];
        $groups = array_merge($groups, $pageGroups);

        // Print each group's info if debug is enabled
        if (!empty($debug)) {
            foreach ($pageGroups as $g) {
                print_r($g);
            }
        }

        // Get next page link if it exists
        $url = $data['@odata.nextLink'] ?? null;
    }

    return !empty($groups) ? $groups[0]['id'] : null;
}

// === Main Logic ===
function main() {
    global $tenantId, $clientId, $clientSecret, $dbConfig, $viewGroupName, $adminEmail;

    echo "Authenticating to Microsoft Graph...\n";
    $token = getAccessToken($tenantId, $clientId, $clientSecret);

    if (!$token) {
        echo "Failed to retrieve access token.\n";
        return;
    }

//    echo "Fetching groups...\n";
//    getGroupList($token);

    echo "Fetching users...\n";
    $allUsers = getAllUsers($token);
    if (empty($allUsers)) {
        echo "No users found in Entra ID.\n";
        return;
    }

    // Detect and remove duplicates
    $counts = array_count_values(array_map('strtolower', $allUsers));
    $duplicates = array_keys(array_filter($counts, fn($count) => $count > 1));
    if (!empty($duplicates)) {
        echo "Warn: Duplicates: " . implode(", ", $duplicates) . "\n";
        $allUsers = array_filter($allUsers, fn($email) => !in_array(strtolower($email), $duplicates));
    }

    echo "Checking for new users...\n";
    createMissingMatomoUsers($allUsers, $dbConfig);

    echo "Fetching group ID for '$viewGroupName'...\n";
    $groupId = getGroupId($token, $viewGroupName);
    if (!$groupId) {
        echo "Group '$viewGroupName' not found in Entra ID.\n";
        return;
    } else {
        echo "Fetching group members of .\n";
        $staffUsers = getGroupMembers($groupId, $token);
        if (empty($staffUsers)) {
            echo "Warning! No members found in '$viewGroupName'.\n";
            return;
        }

        echo "Matching users to Matomo and syncing access for " . count($staffUsers) . " emails...\n";
        grantAccessToAll($staffUsers, $dbConfig);
    }

    // add the admin email to the list
    $allUsers[] = $adminEmail;

    echo "Deleting users not found in Entra...\n";
    deleteMissingMatomoUsers($allUsers, $dbConfig);
}

main();
