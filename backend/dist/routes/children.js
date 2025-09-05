"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const express_validator_1 = require("express-validator");
const database_1 = require("../config/database");
const router = express_1.default.Router();
// Validation middleware
const validateCreateChild = [
    (0, express_validator_1.body)('firstName').trim().isLength({ min: 1 }).withMessage('First name is required'),
    (0, express_validator_1.body)('lastName').trim().isLength({ min: 1 }).withMessage('Last name is required'),
    (0, express_validator_1.body)('dateOfBirth').isISO8601().withMessage('Valid date of birth is required'),
    (0, express_validator_1.body)('gender').isIn(['male', 'female', 'other', 'prefer_not_to_say']).withMessage('Valid gender is required')
];
// GET /api/children - Get all children for the authenticated user
router.get('/', async (req, res) => {
    try {
        const user = req.user;
        let children;
        if (user.role === 'parent') {
            // Parents can see their own children
            children = await (0, database_1.db)('children')
                .where({ parent_id: user.userId })
                .orderBy('created_at', 'desc');
        }
        else if (user.role === 'caregiver') {
            // Caregivers can see children they're assigned to
            children = await (0, database_1.db)('children')
                .join('child_caregivers', 'children.id', 'child_caregivers.child_id')
                .where('child_caregivers.caregiver_id', user.userId)
                .select('children.*')
                .orderBy('children.created_at', 'desc');
        }
        else {
            return res.status(403).json({ error: 'Invalid role' });
        }
        // Add caregiver_ids to each child
        const childrenWithCaregivers = await Promise.all(children.map(async (child) => {
            const caregivers = await (0, database_1.db)('child_caregivers')
                .where({ child_id: child.id })
                .select('caregiver_id');
            const caregiverIds = caregivers.map(c => c.caregiver_id);
            return {
                ...child,
                caregiver_ids: caregiverIds
            };
        }));
        res.json({ children: childrenWithCaregivers });
    }
    catch (error) {
        console.error('GET /children error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /api/children - Create a new child
router.post('/', validateCreateChild, async (req, res) => {
    try {
        const errors = (0, express_validator_1.validationResult)(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }
        const user = req.user;
        // Only parents can create children
        if (user.role !== 'parent') {
            return res.status(403).json({ error: 'Only parents can create children' });
        }
        const { firstName, lastName, dateOfBirth, gender, profileImageURL } = req.body;
        const [childIdResult] = await (0, database_1.db)('children').insert({
            first_name: firstName,
            last_name: lastName,
            date_of_birth: new Date(dateOfBirth),
            gender,
            parent_id: user.userId,
            profile_image_url: profileImageURL || null,
            created_at: new Date(),
            updated_at: new Date()
        }).returning('id');
        const childId = childIdResult.id;
        // Get the created child
        const child = await (0, database_1.db)('children')
            .where({ id: childId })
            .first();
        // Get caregiver IDs for this child
        const caregivers = await (0, database_1.db)('child_caregivers')
            .where({ child_id: childId })
            .select('caregiver_id');
        const caregiverIds = caregivers.map(c => c.caregiver_id);
        // Add caregiver_ids to the child object
        const childWithCaregivers = {
            ...child,
            caregiver_ids: caregiverIds
        };
        res.status(201).json({
            message: 'Child created successfully',
            child: childWithCaregivers
        });
    }
    catch (error) {
        console.error('POST /children error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /api/children/:id - Get a specific child
router.get('/:id', async (req, res) => {
    try {
        const user = req.user;
        const { id } = req.params;
        let child;
        if (user.role === 'parent') {
            child = await (0, database_1.db)('children')
                .where({ id, parent_id: user.userId })
                .first();
        }
        else if (user.role === 'caregiver') {
            child = await (0, database_1.db)('children')
                .join('child_caregivers', 'children.id', 'child_caregivers.child_id')
                .where('children.id', id)
                .where('child_caregivers.caregiver_id', user.userId)
                .select('children.*')
                .first();
        }
        if (!child) {
            return res.status(404).json({ error: 'Child not found' });
        }
        // Get caregiver IDs for this child
        const caregivers = await (0, database_1.db)('child_caregivers')
            .where({ child_id: id })
            .select('caregiver_id');
        const caregiverIds = caregivers.map(c => c.caregiver_id);
        // Add caregiver_ids to the child object
        const childWithCaregivers = {
            ...child,
            caregiver_ids: caregiverIds
        };
        res.json({ child: childWithCaregivers });
    }
    catch (error) {
        console.error('GET /children/:id error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /api/children/:id - Update a child
router.put('/:id', validateCreateChild, async (req, res) => {
    try {
        const errors = (0, express_validator_1.validationResult)(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }
        const user = req.user;
        const { id } = req.params;
        const { firstName, lastName, dateOfBirth, gender, profileImageURL } = req.body;
        // Check if user can access this child
        let child;
        if (user.role === 'parent') {
            child = await (0, database_1.db)('children')
                .where({ id, parent_id: user.userId })
                .first();
        }
        else if (user.role === 'caregiver') {
            child = await (0, database_1.db)('children')
                .join('child_caregivers', 'children.id', 'child_caregivers.child_id')
                .where('children.id', id)
                .where('child_caregivers.caregiver_id', user.userId)
                .select('children.*')
                .first();
        }
        if (!child) {
            return res.status(404).json({ error: 'Child not found' });
        }
        // Only parents can update children
        if (user.role !== 'parent') {
            return res.status(403).json({ error: 'Only parents can update children' });
        }
        await (0, database_1.db)('children')
            .where({ id })
            .update({
            first_name: firstName,
            last_name: lastName,
            date_of_birth: new Date(dateOfBirth),
            gender,
            profile_image_url: profileImageURL || null,
            updated_at: new Date()
        });
        // Get the updated child
        const updatedChild = await (0, database_1.db)('children')
            .where({ id })
            .first();
        res.json({
            message: 'Child updated successfully',
            child: updatedChild
        });
    }
    catch (error) {
        console.error('PUT /children/:id error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// DELETE /api/children/:id - Delete a child
router.delete('/:id', async (req, res) => {
    try {
        const user = req.user;
        const { id } = req.params;
        // Only parents can delete children
        if (user.role !== 'parent') {
            return res.status(403).json({ error: 'Only parents can delete children' });
        }
        const child = await (0, database_1.db)('children')
            .where({ id, parent_id: user.userId })
            .first();
        if (!child) {
            return res.status(404).json({ error: 'Child not found' });
        }
        // Delete related records first
        await (0, database_1.db)('child_caregivers').where({ child_id: id }).del();
        await (0, database_1.db)('schedule_templates').where({ child_id: id }).del();
        await (0, database_1.db)('schedules').where({ child_id: id }).del();
        // Delete the child
        await (0, database_1.db)('children').where({ id }).del();
        res.json({ message: 'Child deleted successfully' });
    }
    catch (error) {
        console.error('DELETE /children/:id error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
exports.default = router;
