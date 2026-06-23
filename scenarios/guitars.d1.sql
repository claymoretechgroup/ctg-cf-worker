-- Guitar Collection Database — D1 (SQLite)
-- Ported from ctg-php-staging/data/guitars.sql (MariaDB).
--
-- Transform notes (MariaDB -> SQLite/D1):
--   * INT AUTO_INCREMENT PRIMARY KEY  -> INTEGER PRIMARY KEY AUTOINCREMENT
--   * YEAR                            -> INTEGER (SQLite has no YEAR type)
--   * ENUM(...)                       -> TEXT + CHECK(col IN (...))
--   * VARCHAR(n)                      -> TEXT (length not enforced by SQLite)
-- Everything else (IF NOT EXISTS, FOREIGN KEY, the INSERTs) carries over as-is.
-- General rules for porting an arbitrary MariaDB schema: see the README
-- "Porting a MariaDB schema to D1" recipe.

CREATE TABLE IF NOT EXISTS guitars (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    make TEXT NOT NULL,
    model TEXT NOT NULL,
    color TEXT NOT NULL,
    year_purchased INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS pickups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    guitar_id INTEGER NOT NULL,
    position TEXT NOT NULL CHECK (position IN ('neck', 'middle', 'bridge')),
    type     TEXT NOT NULL CHECK (type IN ('single_coil', 'humbucker', 'active')),
    make TEXT NOT NULL,
    model TEXT NOT NULL,
    FOREIGN KEY (guitar_id) REFERENCES guitars(id)
);

-- Guitars
INSERT INTO guitars (id, make, model, color, year_purchased) VALUES
(1, 'Ibanez', 'GRX20L', 'Black', 2001),
(2, 'Schecter', 'Omen-6', 'Black', 2002),
(3, 'Fender', 'Standard Stratocaster', 'Black/White', 2003),
(4, 'Fender', 'Telecaster MOD Shop', 'Lake Placid Blue', 2019),
(5, 'Gibson', 'Les Paul Studio 2019', 'BBQ Burst', 2020),
(6, 'Ibanez', 'RG Prestige RG652AHML', 'Nebula Green Burst', 2021),
(7, 'Fender', 'Stratocaster MOD Shop', 'Silverburst', 2022),
(8, 'ESP', 'LTD EC-1000T CTM', 'Violet Shadow', 2023),
(9, 'Schecter', 'Hellraiser Hybrid C-7', 'Trans Black Burst', 2024);

-- Pickups
INSERT INTO pickups (guitar_id, position, type, make, model) VALUES
-- Guitar 1: Ibanez GRX20L
(1, 'neck', 'humbucker', 'USA Jackson', 'Unknown USA Model'),
(1, 'bridge', 'humbucker', 'Seymour Duncan', 'SH-JB'),
-- Guitar 2: Schecter Omen-6
(2, 'neck', 'humbucker', 'DiMarzio', 'Evolution'),
(2, 'bridge', 'humbucker', 'DiMarzio', 'Tone Zone'),
-- Guitar 3: Fender Standard Stratocaster
(3, 'neck', 'single_coil', 'DiMarzio', 'YJM'),
(3, 'middle', 'humbucker', 'Seymour Duncan', 'SH-JB Jr.'),
(3, 'bridge', 'humbucker', 'Seymour Duncan', 'Hot Rails For Strat'),
-- Guitar 4: Fender Telecaster MOD Shop
(4, 'neck', 'single_coil', 'Fender', 'Texas Special'),
(4, 'bridge', 'single_coil', 'Fender', 'Texas Special'),
-- Guitar 5: Gibson Les Paul Studio 2019
(5, 'neck', 'humbucker', 'Gibson', '490R'),
(5, 'bridge', 'humbucker', 'Gibson', '498T'),
-- Guitar 6: Ibanez RG Prestige RG652AHML
(6, 'neck', 'humbucker', 'Seymour Duncan', 'Full Shred'),
(6, 'bridge', 'humbucker', 'Seymour Duncan', 'Perpetual Burn'),
-- Guitar 7: Fender Stratocaster MOD Shop
(7, 'neck', 'single_coil', 'Fralin', 'Blues Special'),
(7, 'middle', 'single_coil', 'Fralin', 'Blues Special'),
(7, 'bridge', 'single_coil', 'Fralin', 'Woodstock'),
-- Guitar 8: ESP LTD EC-1000T CTM
(8, 'neck', 'humbucker', 'DiMarzio', 'LiquiFire'),
(8, 'bridge', 'humbucker', 'Seymour Duncan', 'Custom Custom'),
-- Guitar 9: Schecter Hellraiser Hybrid C-7
(9, 'neck', 'active', 'EMG', '66-7'),
(9, 'bridge', 'active', 'EMG', '57-7');
