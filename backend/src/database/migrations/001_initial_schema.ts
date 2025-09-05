import type { Knex } from 'knex';

export async function up(knex: Knex): Promise<void> {
  // Users table
  await knex.schema.createTable('users', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.string('email').unique().notNullable();
    table.string('password_hash').notNullable();
    table.string('first_name').notNullable();
    table.string('last_name').notNullable();
    table.enum('role', ['parent', 'caregiver']).notNullable();
    table.string('profile_image_url');
    table.string('firebase_token');
    table.timestamps(true, true);
    
    // Indexes
    table.index(['email']);
    table.index(['role']);
  });

  // Children table
  await knex.schema.createTable('children', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.string('first_name').notNullable();
    table.string('last_name').notNullable();
    table.date('date_of_birth').notNullable();
    table.enum('gender', ['male', 'female', 'other', 'prefer_not_to_say']).notNullable();
    table.string('profile_image_url');
    table.uuid('parent_id').references('id').inTable('users').onDelete('CASCADE');
    table.timestamps(true, true);
    
    // Indexes
    table.index(['parent_id']);
  });

  // Child-caregiver relationships
  await knex.schema.createTable('child_caregivers', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('child_id').references('id').inTable('children').onDelete('CASCADE');
    table.uuid('caregiver_id').references('id').inTable('users').onDelete('CASCADE');
    table.timestamps(true, true);
    
    // Unique constraint
    table.unique(['child_id', 'caregiver_id']);
    
    // Indexes
    table.index(['child_id']);
    table.index(['caregiver_id']);
  });

  // Schedules table
  await knex.schema.createTable('schedules', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('child_id').references('id').inTable('children').onDelete('CASCADE');
    table.enum('type', ['medicine', 'feeding', 'milk']).notNullable();
    table.string('title').notNullable();
    table.text('description');
    table.timestamp('scheduled_time').notNullable();
    table.enum('status', ['scheduled', 'completed', 'missed', 'skipped']).defaultTo('scheduled');
    table.text('notes');
    table.uuid('created_by').references('id').inTable('users').onDelete('SET NULL');
    table.timestamp('completed_at');
    table.timestamps(true, true);
    
    // Indexes
    table.index(['child_id']);
    table.index(['scheduled_time']);
    table.index(['status']);
    table.index(['type']);
  });

  // Feed items table
  await knex.schema.createTable('feed_items', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('child_id').references('id').inTable('children').onDelete('CASCADE');
    table.string('title').notNullable();
    table.text('content');
    table.enum('content_type', ['note', 'photo', 'video']).notNullable();
    table.jsonb('media_urls');
    table.uuid('created_by').references('id').inTable('users').onDelete('SET NULL');
    table.timestamps(true, true);
    
    // Indexes
    table.index(['child_id']);
    table.index(['content_type']);
    table.index(['created_at']);
  });

  // Comments table
  await knex.schema.createTable('comments', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('feed_item_id').references('id').inTable('feed_items').onDelete('CASCADE');
    table.text('content').notNullable();
    table.uuid('created_by').references('id').inTable('users').onDelete('SET NULL');
    table.timestamps(true, true);
    
    // Indexes
    table.index(['feed_item_id']);
    table.index(['created_at']);
  });

  // Sync data table (for temporary storage)
  await knex.schema.createTable('sync_data', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('sender_id').references('id').inTable('users').onDelete('CASCADE');
    table.uuid('recipient_id').references('id').inTable('users').onDelete('CASCADE');
    table.string('data_type').notNullable(); // 'schedule', 'feed_item', 'comment'
    table.jsonb('encrypted_data').notNullable();
    table.boolean('delivered').defaultTo(false);
    table.timestamp('delivered_at');
    table.timestamp('expires_at').notNullable(); // Auto-delete after this time
    table.timestamps(true, true);
    
    // Indexes
    table.index(['sender_id']);
    table.index(['recipient_id']);
    table.index(['delivered']);
    table.index(['expires_at']);
  });
}

export async function down(knex: Knex): Promise<void> {
  await knex.schema.dropTableIfExists('sync_data');
  await knex.schema.dropTableIfExists('comments');
  await knex.schema.dropTableIfExists('feed_items');
  await knex.schema.dropTableIfExists('schedules');
  await knex.schema.dropTableIfExists('child_caregivers');
  await knex.schema.dropTableIfExists('children');
  await knex.schema.dropTableIfExists('users');
} 