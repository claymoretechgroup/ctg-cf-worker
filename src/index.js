// CTG CF Staging — smoke-test Worker.
//
// Mirrors the role of the PHP staging index page: a live connection check
// against the staging datastores. Hit the Worker root and you should get a
// JSON payload listing the seeded guitars (D1) and the seeded objects (R2).
// If both come back green, your bindings and seed data are wired correctly.
//
// R2 is checked via env.BUCKET.list() — the Worker binding is the source of
// truth, which sidesteps the CLI-vs-binding local-store divergence in
// workers-sdk #13034.

export default {
  async fetch(request, env) {
    const { results } = await env.DB.prepare(
      `SELECT g.id, g.make, g.model, g.color, g.year_purchased,
              COUNT(p.id) AS pickup_count
         FROM guitars g
         LEFT JOIN pickups p ON p.guitar_id = g.id
        GROUP BY g.id
        ORDER BY g.year_purchased`
    ).all();

    const listing = await env.BUCKET.list();

    return Response.json({
      ok: true,
      d1: { count: results.length, guitars: results },
      r2: { count: listing.objects.length, keys: listing.objects.map((o) => o.key) },
    });
  },
};
