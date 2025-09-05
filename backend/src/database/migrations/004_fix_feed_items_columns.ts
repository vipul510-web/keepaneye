import type { Knex } from 'knex';

export async function up(knex: Knex): Promise<void> {
  const hasTable = await knex.schema.hasTable('feed_items');
  if (!hasTable) return;

  const hasIsPinned = await knex.schema.hasColumn('feed_items', 'is_pinned');
  if (!hasIsPinned) {
    await knex.schema.alterTable('feed_items', (table) => {
      table.boolean('is_pinned').defaultTo(false);
    });
  }
}

export async function down(knex: Knex): Promise<void> {
  const hasTable = await knex.schema.hasTable('feed_items');
  if (!hasTable) return;

  const hasIsPinned = await knex.schema.hasColumn('feed_items', 'is_pinned');
  if (hasIsPinned) {
    await knex.schema.alterTable('feed_items', (table) => {
      table.dropColumn('is_pinned');
    });
  }
}
