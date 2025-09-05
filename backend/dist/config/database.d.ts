import knex from 'knex';
export declare const db: knex.Knex<any, unknown[]>;
export declare function initializeDatabase(): Promise<void>;
export declare function closeDatabase(): Promise<void>;
export default db;
//# sourceMappingURL=database.d.ts.map