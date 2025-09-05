import type { Knex } from 'knex';

export async function up(knex: Knex): Promise<void> {
  // 1) Expand schedules.type allowed values by replacing CHECK constraint
  // Attempt to drop known constraint name; ignore if it doesn't exist
  try {
    await knex.raw('ALTER TABLE "schedules" DROP CONSTRAINT IF EXISTS "schedules_type_check"');
  } catch (e) {
    // ignore
  }
  // Add new CHECK constraint allowing broader set
  try {
    await knex.raw(
      "ALTER TABLE \"schedules\" ADD CONSTRAINT \"schedules_type_check\" CHECK (type IN ('medicine','feeding','milk','nap','diaper','bath','play','other'))"
    );
  } catch (e) {
    // if already added by prior run, ignore
  }

  // 2) Create schedule_templates table
  await knex.schema.createTable('schedule_templates', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('child_id').references('id').inTable('children').onDelete('CASCADE');
    table.enum('type', ['medicine', 'feeding', 'milk', 'nap', 'diaper', 'bath', 'play', 'other']).notNullable();
    table.string('title').notNullable();
    table.text('description');
    table.time('time_of_day').notNullable();
    table.enum('frequency', ['daily', 'weekly', 'monthly']).notNullable().defaultTo('daily');
    table.integer('weekday'); // 1-7 for weekly (Sun=1)
    table.text('notes');
    table.uuid('created_by').references('id').inTable('users').onDelete('SET NULL');
    table.boolean('is_active').notNullable().defaultTo(true);
    table.timestamps(true, true);

    table.index(['child_id']);
    table.index(['frequency']);
    table.index(['weekday']);
    table.index(['type']);
  });

  // 3) Add template_id and has_been_modified to schedules
  await knex.schema.alterTable('schedules', (table) => {
    table.uuid('template_id').references('id').inTable('schedule_templates').onDelete('SET NULL');
    table.boolean('has_been_modified').notNullable().defaultTo(false);
  });
}

export async function down(knex: Knex): Promise<void> {
  // Remove added columns from schedules first
  await knex.schema.alterTable('schedules', (table) => {
    table.dropColumn('template_id');
    table.dropColumn('has_been_modified');
  });

  // Drop schedule_templates
  await knex.schema.dropTableIfExists('schedule_templates');

  // Restore original schedules.type CHECK constraint (medicine, feeding, milk)
  try {
    await knex.raw('ALTER TABLE "schedules" DROP CONSTRAINT IF EXISTS "schedules_type_check"');
    await knex.raw(
      "ALTER TABLE \"schedules\" ADD CONSTRAINT \"schedules_type_check\" CHECK (type IN ('medicine','feeding','milk'))"
    );
  } catch (e) {
    // ignore
  }
} 