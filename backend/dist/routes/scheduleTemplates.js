"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const database_1 = require("../config/database");
const router = express_1.default.Router();
async function canAccessChild(userId, role, childId) {
    if (role === 'parent') {
        const child = await (0, database_1.db)('children').where({ id: childId, parent_id: userId }).first();
        return !!child;
    }
    if (role === 'caregiver') {
        const rel = await (0, database_1.db)('child_caregivers').where({ child_id: childId, caregiver_id: userId }).first();
        return !!rel;
    }
    return false;
}
// GET /api/schedule-templates?childId=...
router.get('/', async (req, res) => {
    try {
        const user = req.user;
        const { childId } = req.query;
        if (!childId)
            return res.status(400).json({ error: 'childId is required' });
        const allowed = await canAccessChild(user.userId, user.role, childId);
        if (!allowed)
            return res.status(403).json({ error: 'Forbidden' });
        const templates = await (0, database_1.db)('schedule_templates')
            .where({ child_id: childId, is_active: true })
            .orderBy(['frequency', { column: 'weekday', order: 'asc' }, { column: 'time_of_day', order: 'asc' }]);
        res.json({ templates });
    }
    catch (error) {
        console.error('GET /schedule-templates error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /api/schedule-templates/bulk-upsert { childId, items: [{ title, type, description, timeOfDay, frequency, weekday }] }
router.post('/bulk-upsert', async (req, res) => {
    try {
        const user = req.user;
        const { childId, items } = req.body;
        if (!childId || !Array.isArray(items))
            return res.status(400).json({ error: 'childId and items[] are required' });
        const allowed = await canAccessChild(user.userId, user.role, childId);
        if (!allowed)
            return res.status(403).json({ error: 'Forbidden' });
        const results = [];
        for (const it of items) {
            // try to find existing exact match (including inactive ones to avoid recreation)
            const existing = await (0, database_1.db)('schedule_templates')
                .where({
                child_id: childId,
                type: it.type,
                title: it.title,
                frequency: it.frequency,
                weekday: it.weekday ?? null,
            })
                .andWhere('time_of_day', it.timeOfDay)
                .first();
            if (existing) {
                // If template exists but is inactive, reactivate it and update
                if (!existing.is_active) {
                    await (0, database_1.db)('schedule_templates').where({ id: existing.id }).update({
                        is_active: true,
                        description: it.description ?? existing.description,
                        notes: it.notes ?? existing.notes,
                        updated_at: new Date()
                    });
                }
                else {
                    // update description/notes if changed
                    const updates = {};
                    if (it.description !== undefined)
                        updates.description = it.description;
                    if (it.notes !== undefined)
                        updates.notes = it.notes;
                    if (Object.keys(updates).length > 0) {
                        updates.updated_at = new Date();
                        await (0, database_1.db)('schedule_templates').where({ id: existing.id }).update(updates);
                    }
                }
                results.push({ id: existing.id, created: false });
            }
            else {
                const [idResult] = await (0, database_1.db)('schedule_templates').insert({
                    child_id: childId,
                    type: it.type,
                    title: it.title,
                    description: it.description ?? null,
                    time_of_day: it.timeOfDay,
                    frequency: it.frequency,
                    weekday: it.weekday ?? null,
                    notes: it.notes ?? null,
                    created_by: user.userId,
                    is_active: true,
                    created_at: new Date(),
                    updated_at: new Date(),
                }).returning('id');
                results.push({ id: idResult.id, created: true });
            }
        }
        res.json({ results });
    }
    catch (error) {
        console.error('POST /schedule-templates/bulk-upsert error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// DELETE /api/schedule-templates/:id
router.delete('/:id', async (req, res) => {
    try {
        const user = req.user;
        const id = req.params.id;
        const tpl = await (0, database_1.db)('schedule_templates').where({ id }).first();
        if (!tpl)
            return res.status(404).json({ error: 'Template not found' });
        const allowed = await canAccessChild(user.userId, user.role, tpl.child_id);
        if (!allowed)
            return res.status(403).json({ error: 'Forbidden' });
        // Delete all schedules that reference this template
        const deletedSchedules = await (0, database_1.db)('schedules').where({ template_id: id }).del();
        console.log(`🗑️ Deleted ${deletedSchedules} schedules for template ${id}`);
        // Deactivate the template
        await (0, database_1.db)('schedule_templates').where({ id }).update({ is_active: false, updated_at: new Date() });
        console.log(`🗑️ Deactivated template ${id} for child ${tpl.child_id}`);
        res.json({
            message: 'Template deactivated and schedules deleted',
            childId: tpl.child_id
        });
    }
    catch (error) {
        console.error('DELETE /schedule-templates/:id error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
exports.default = router;
