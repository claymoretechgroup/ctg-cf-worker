// D1 scenario verbs. Invoked by the package.json scripts; the verb is the
// first arg, any user value follows after `--`:
//
//   npm run load-scenario -- with-prs
//   npm run dump          -- snapshot
//   npm run query         -- "SELECT * FROM guitars"
//   npm run load-remote   -- guitars
//   npm run dump-remote   -- prod-snapshot

import { DB, LOCAL, wrangler } from "./lib.js";

const [verb, value] = process.argv.slice(2);

function need(usage) {
  if (!value) {
    console.error(usage);
    process.exit(1);
  }
}

switch (verb) {
  case "load-scenario":
    need("Usage: npm run load-scenario -- <name>   (scenarios/<name>.d1.sql)");
    wrangler(["d1", "execute", DB, ...LOCAL, `--file=scenarios/${value}.d1.sql`]);
    break;
  case "dump":
    need("Usage: npm run dump -- <name>   (scenarios/<name>.d1.sql)");
    wrangler(["d1", "export", DB, ...LOCAL, `--output=scenarios/${value}.d1.sql`]);
    break;
  case "query":
    need('Usage: npm run query -- "SELECT * FROM guitars"');
    wrangler(["d1", "execute", DB, ...LOCAL, "--command", value]);
    break;
  case "load-remote":
    need("Usage: npm run load-remote -- <name>   (scenarios/<name>.d1.sql)");
    wrangler(["d1", "execute", DB, "--remote", `--file=scenarios/${value}.d1.sql`]);
    break;
  case "dump-remote":
    need("Usage: npm run dump-remote -- <name>   (scenarios/<name>.d1.sql)");
    wrangler(["d1", "export", DB, "--remote", `--output=scenarios/${value}.d1.sql`]);
    break;
  default:
    console.error(`Unknown d1 verb: ${verb}`);
    process.exit(1);
}
