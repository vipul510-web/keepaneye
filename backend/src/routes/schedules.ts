import express from 'express';
import { db } from '../config/database';

const router = express.Router();

// Helper: RBAC check - ensure requester can access child
async function canAccessChild(userId: string, role: string, childId: string): Promise<boolean> {
  if (role === 'parent') {
    const child = await db('children').where({ id: childId, parent_id: userId }).first();
    return !!child;
  }
  if (role === 'caregiver') {
    const rel = await db('child_caregivers').where({ child_id: childId, caregiver_id: userId }).first();
    return !!rel;
  }
  return false;
}

// GET /api/schedules?childId=...&date=YYYY-MM-DD
router.get('/', async (req, res) => {
  try {
    const user = req.user!;
    const { childId, date } = req.query as { childId?: string; date?: string };

    if (!childId || !date) {
      return res.status(400).json({ error: 'childId and date are required' });
    }

    const allowed = await canAccessChild(user.userId, user.role, childId);
    if (!allowed) return res.status(403).json({ error: 'Forbidden' });

    const start = new Date(date);
    const end = new Date(start);
    end.setDate(start.getDate() + 1);

    const schedules = await db('schedules')
      .where('child_id', childId)
      .andWhere('scheduled_time', '>=', start)
      .andWhere('scheduled_time', '<', end)
      .orderBy('scheduled_time', 'asc');

    res.json({ schedules });
  } catch (error) {
    console.error('GET /schedules error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/schedules/generate { childId, dates: [YYYY-MM-DD] }
router.post('/generate', async (req, res) => {
  try {
    const user = req.user!;
    const { childId, dates } = req.body as { childId?: string; dates?: string[] };

    if (!childId || !Array.isArray(dates) || dates.length === 0) {
      return res.status(400).json({ error: 'childId and dates[] are required' });
    }

    const allowed = await canAccessChild(user.userId, user.role, childId);
    if (!allowed) return res.status(403).json({ error: 'Forbidden' });

    // Fetch active templates for child
    const templates = await db('schedule_templates')
      .where({ child_id: childId, is_active: true });

    // Get all template IDs (active and inactive) for cleanup
    const allTemplateIds = await db('schedule_templates')
      .where({ child_id: childId })
      .select('id');

    const results: any[] = [];

    for (const dateStr of dates) {
      const target = new Date(dateStr);
      const start = new Date(target);
      const end = new Date(target);
      end.setDate(start.getDate() + 1);

      const weekday = target.getDay() === 0 ? 1 : target.getDay() + 1; // Map JS Sun(0)..Sat(6) -> 1..7

      // Clean up any schedules for this date that don't have active templates
      const activeTemplateIds = templates.map(t => t.id);
      const deletedSchedules = await db('schedules')
        .where({ child_id: childId })
        .andWhere('scheduled_time', '>=', start)
        .andWhere('scheduled_time', '<', end)
        .whereNotIn('template_id', activeTemplateIds)
        .del();
      
      if (deletedSchedules > 0) {
        console.log(`🗑️ Cleaned up ${deletedSchedules} orphaned schedules for ${dateStr}`);
      }

      for (const tpl of templates) {
        // Frequency filter
        let shouldGenerate = false;
        if (tpl.frequency === 'daily') shouldGenerate = true;
        else if (tpl.frequency === 'weekly') shouldGenerate = tpl.weekday === weekday;
        else if (tpl.frequency === 'monthly') shouldGenerate = true; // optionally match day-of-month later

        console.log(`🔍 Template '${tpl.title}' (weekday: ${tpl.weekday}) vs target weekday: ${weekday} -> shouldGenerate: ${shouldGenerate}`);

        if (!shouldGenerate) continue;

        // Build scheduled_time combining date + template time_of_day
        const [hours, minutes, seconds] = (tpl.time_of_day as string).split(':').map((s: string) => parseInt(s, 10));
        const scheduledTime = new Date(start);
        scheduledTime.setHours(hours || 0, minutes || 0, 0, 0);

        // Idempotency: does a schedule exist for this template on this date?
        const existing = await db('schedules')
          .where({ child_id: childId, template_id: tpl.id })
          .andWhere('scheduled_time', '>=', start)
          .andWhere('scheduled_time', '<', end)
          .first();

        if (existing) {
          results.push({ date: dateStr, templateId: tpl.id, scheduleId: existing.id, created: false });
          continue;
        }

        const [createdResult] = await db('schedules').insert({
          child_id: childId,
          template_id: tpl.id,
          type: tpl.type,
          title: tpl.title,
          description: tpl.description,
          scheduled_time: scheduledTime,
          status: 'scheduled',
          notes: tpl.notes,
          created_by: user.userId,
          created_at: new Date(),
          updated_at: new Date(),
          has_been_modified: false,
        }).returning('id');

        results.push({ date: dateStr, templateId: tpl.id, scheduleId: createdResult.id, created: true });
      }
    }

    res.json({ results });
  } catch (error) {
    console.error('POST /schedules/generate error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PATCH /api/schedules/:id - update title/time/status/notes
router.patch('/:id', async (req, res) => {
  try {
    const user = req.user!;
    const scheduleId = req.params.id;
    const payload = req.body as Partial<{ title: string; description: string; status: string; scheduled_time: string; notes: string }>;

    const schedule = await db('schedules').where({ id: scheduleId }).first();
    if (!schedule) return res.status(404).json({ error: 'Schedule not found' });

    const allowed = await canAccessChild(user.userId, user.role, schedule.child_id);
    if (!allowed) return res.status(403).json({ error: 'Forbidden' });

    const updates: any = { updated_at: new Date() };
    if (payload.title !== undefined) updates.title = payload.title;
    if (payload.description !== undefined) updates.description = payload.description;
    if (payload.status !== undefined) updates.status = payload.status;
    if (payload.notes !== undefined) updates.notes = payload.notes;
    if (payload.scheduled_time !== undefined) updates.scheduled_time = new Date(payload.scheduled_time);

    // Mark as modified if any user-editing field is changed
    if (updates.title !== undefined || updates.description !== undefined || updates.scheduled_time !== undefined || updates.notes !== undefined) {
      updates.has_been_modified = true;
    }

    const [updated] = await db('schedules').where({ id: scheduleId }).update(updates).returning('*');
    res.json({ schedule: updated });
  } catch (error) {
    console.error('PATCH /schedules/:id error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router; 
 
// POST /api/schedules/replace
// Replaces schedules for a child over a time horizon based on provided plan (no templates)
// Body: {
//   childId: string,
//   plan: Array<{ title: string; type: string; description?: string; timeOfDay: string; weekdays: number[]; notes?: string }>,
//   startDate?: string (YYYY-MM-DD),
//   weeks?: number (default 8)
// }
router.post('/replace', async (req, res) => {
  try {
    const user = req.user!;
    const { childId, plan, startDate, weeks } = req.body as {
      childId?: string;
      plan?: Array<{ title: string; type: string; description?: string; timeOfDay: string; weekdays: number[]; notes?: string }>;
      startDate?: string;
      weeks?: number;
    };

    if (!childId || !Array.isArray(plan)) {
      return res.status(400).json({ error: 'childId and plan are required' });
    }

    const allowed = await canAccessChild(user.userId, user.role, childId);
    if (!allowed) return res.status(403).json({ error: 'Forbidden' });

    const horizonWeeks = typeof weeks === 'number' && weeks > 0 ? Math.min(26, weeks) : 8; // cap at 26 weeks

    const start = startDate ? new Date(startDate) : new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + horizonWeeks * 7);

    // Delete only non-modified schedules in horizon to preserve manual edits
    const deleted = await db('schedules')
      .where({ child_id: childId, has_been_modified: false })
      .andWhere('scheduled_time', '>=', start)
      .andWhere('scheduled_time', '<', end)
      .del();
    if (deleted > 0) {
      console.log(`🗑️ Replaced plan: deleted ${deleted} non-modified schedules for child ${childId}`);
    }

    // Generate new schedules based on plan
    const toInsert: any[] = [];
    const cursor = new Date(start);
    while (cursor < end) {
      // Map JS weekday (0..6) to 1..7 (Sun=1)
      const weekday = cursor.getDay() === 0 ? 1 : cursor.getDay() + 1;
      for (const item of plan) {
        if (!item.weekdays?.includes(weekday)) continue;
        const [h, m, s] = (item.timeOfDay || '00:00:00').split(':').map((v: string) => parseInt(v, 10));
        const scheduled = new Date(cursor);
        scheduled.setHours(h || 0, m || 0, 0, 0);
        toInsert.push({
          child_id: childId,
          template_id: null, // no template linkage in simplified flow
          type: item.type,
          title: item.title,
          description: item.description ?? null,
          scheduled_time: scheduled,
          status: 'scheduled',
          notes: item.notes ?? null,
          created_by: user.userId,
          created_at: new Date(),
          updated_at: new Date(),
          has_been_modified: false,
        });
      }
      cursor.setDate(cursor.getDate() + 1);
    }

    let inserted = 0;
    if (toInsert.length > 0) {
      const chunks = 1000;
      for (let i = 0; i < toInsert.length; i += chunks) {
        const batch = toInsert.slice(i, i + chunks);
        await db('schedules').insert(batch);
        inserted += batch.length;
      }
    }

    res.json({ deleted, created: inserted });
  } catch (error) {
    console.error('POST /schedules/replace error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/schedules/:id — delete a single scheduled instance
router.delete('/:id', async (req, res) => {
  try {
    const user = req.user!;
    const id = req.params.id;
    const schedule = await db('schedules').where({ id }).first();
    if (!schedule) return res.status(404).json({ error: 'Schedule not found' });

    // Authorization: parent must own the child, caregiver must be assigned to the child
    const canParent = await db('children').where({ id: schedule.child_id, parent_id: user.userId }).first();
    let canCaregiver = false;
    if (!canParent) {
      const rel = await db('child_caregivers').where({ child_id: schedule.child_id, caregiver_id: user.userId }).first();
      canCaregiver = !!rel;
    }
    if (!canParent && !canCaregiver) return res.status(403).json({ error: 'Forbidden' });

    await db('schedules').where({ id }).del();
    return res.json({ message: 'Schedule deleted', id });
  } catch (error) {
    console.error('DELETE /schedules/:id error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});