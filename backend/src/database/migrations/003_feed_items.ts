import type { Knex } from 'knex';

export async function up(knex: Knex): Promise<void> {
  const exists = await knex.schema.hasTable('feed_items');
  if (exists) {
    return; // Table already exists; skip creation to avoid startup failure
  }
  await knex.schema.createTable('feed_items', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('child_id').notNullable().references('id').inTable('children').onDelete('CASCADE');
    table.string('title').notNullable();
    table.text('content').notNullable();
    table.enum('content_type', ['note', 'photo', 'video']).notNullable().defaultTo('note');
    table.jsonb('media_urls').defaultTo('[]');
    table.uuid('created_by').notNullable().references('id').inTable('users').onDelete('CASCADE');
    table.boolean('is_pinned').defaultTo(false);
    table.timestamp('created_at').defaultTo(knex.fn.now());
    table.timestamp('updated_at').defaultTo(knex.fn.now());

    table.index(['child_id']);
    table.index(['created_by']);
    table.index(['created_at']);
    table.index(['is_pinned']);
  });
}

export async function down(knex: Knex): Promise<void> {
  const exists = await knex.schema.hasTable('feed_items');
  if (exists) {
    await knex.schema.dropTable('feed_items');
  }
}
