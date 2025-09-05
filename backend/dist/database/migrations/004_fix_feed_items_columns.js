"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.up = up;
exports.down = down;
async function up(knex) {
    const hasTable = await knex.schema.hasTable('feed_items');
    if (!hasTable)
        return;
    const hasIsPinned = await knex.schema.hasColumn('feed_items', 'is_pinned');
    if (!hasIsPinned) {
        await knex.schema.alterTable('feed_items', (table) => {
            table.boolean('is_pinned').defaultTo(false);
        });
    }
}
async function down(knex) {
    const hasTable = await knex.schema.hasTable('feed_items');
    if (!hasTable)
        return;
    const hasIsPinned = await knex.schema.hasColumn('feed_items', 'is_pinned');
    if (hasIsPinned) {
        await knex.schema.alterTable('feed_items', (table) => {
            table.dropColumn('is_pinned');
        });
    }
}
