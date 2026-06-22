// CTG CF Staging — smoke-test Worker.
//
// Mirrors the role of the PHP staging index page: a live connection check
// against the staging datastore. Hit the Worker root and you should get a
// JSON payload listing the seeded guitars and their pickup counts. If that
// comes back green, your D1 binding and seed scenario are wired correctly.

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

    return Response.json({
      ok: true,
      datastore: "d1",
      count: results.length,
      guitars: results,
    });
  },
};
