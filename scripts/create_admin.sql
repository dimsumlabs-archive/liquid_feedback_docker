INSERT INTO "member" (
        "login",
        "password",
        "active",
        "admin",
        "name",
        "activated",
        "last_activity"
    ) VALUES (
        'admin',
        '$1$.EMPTY.$LDufa24OE2HZFXAXh71Eb1',
        TRUE,
        TRUE,
        'Administrator',
        NOW(),
        NOW()
    );