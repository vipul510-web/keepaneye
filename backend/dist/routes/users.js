"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const express_validator_1 = require("express-validator");
const database_1 = require("../config/database");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const router = express_1.default.Router();
// Get all caregivers for a parent
router.get('/caregivers', auth_1.requireAuth, (0, errorHandler_1.asyncHandler)(async (req, res) => {
    const userId = req.user.userId;
    const userRole = req.user.role;
    if (userRole !== 'parent') {
        return res.status(403).json({ error: 'Only parents can view their caregivers' });
    }
    // Get all children for this parent
    const children = await (0, database_1.db)('children')
        .where({ parent_id: userId })
        .select('id');
    const childIds = children.map(child => child.id);
    if (childIds.length === 0) {
        return res.json({ caregivers: [] });
    }
    // Get all caregivers assigned to any of the parent's children
    const caregivers = await (0, database_1.db)('child_caregivers as cc')
        .join('users as u', 'cc.caregiver_id', 'u.id')
        .join('children as c', 'cc.child_id', 'c.id')
        .select('u.id', 'u.first_name', 'u.last_name', 'u.email', 'u.role', 'u.profile_image_url', 'cc.child_id', 'cc.created_at as added_at')
        .whereIn('cc.child_id', childIds)
        .orderBy('u.first_name', 'asc');
    // Group caregivers by their ID to avoid duplicates
    const uniqueCaregivers = caregivers.reduce((acc, caregiver) => {
        if (!acc[caregiver.id]) {
            acc[caregiver.id] = {
                id: caregiver.id,
                firstName: caregiver.first_name,
                lastName: caregiver.last_name,
                email: caregiver.email,
                role: 'other', // Default to 'other' for caregiver role mapping
                profileImageURL: caregiver.profile_image_url,
                assignedChildIds: [],
                createdBy: userId,
                createdAt: caregiver.added_at,
                updatedAt: caregiver.added_at, // Use added_at as updatedAt since we don't track updates
                isActive: true // Default to active since we don't track deactivation
            };
        }
        acc[caregiver.id].assignedChildIds.push(caregiver.child_id);
        return acc;
    }, {});
    res.json({ caregivers: Object.values(uniqueCaregivers) });
}));
// Get all caregivers for a child
router.get('/caregivers/:childId', auth_1.requireAuth, (0, errorHandler_1.asyncHandler)(async (req, res) => {
    const { childId } = req.params;
    const userId = req.user.userId;
    // Check if user has access to this child
    const child = await (0, database_1.db)('children')
        .where({ id: childId })
        .first();
    if (!child) {
        return res.status(404).json({ error: 'Child not found' });
    }
    // Only parent or caregivers can view caregivers
    if (child.parent_id !== userId) {
        const caregiverAccess = await (0, database_1.db)('child_caregivers')
            .where({ child_id: childId, caregiver_id: userId })
            .first();
        if (!caregiverAccess) {
            return res.status(403).json({ error: 'Access denied' });
        }
    }
    // Get caregivers
    const caregivers = await (0, database_1.db)('child_caregivers as cc')
        .join('users as u', 'cc.caregiver_id', 'u.id')
        .select('u.id', 'u.first_name', 'u.last_name', 'u.email', 'u.role', 'u.profile_image_url', 'cc.created_at as added_at')
        .where({ 'cc.child_id': childId });
    res.json({ caregivers });
}));
// Add caregiver to child (parent only)
router.post('/caregivers/:childId', auth_1.requireParent, (0, errorHandler_1.asyncHandler)(async (req, res) => {
    const { childId } = req.params;
    const { caregiverEmail } = req.body;
    const parentId = req.user.userId;
    // Validate input
    const errors = (0, express_validator_1.validationResult)(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }
    // Check if child exists and belongs to parent
    const child = await (0, database_1.db)('children')
        .where({ id: childId, parent_id: parentId })
        .first();
    if (!child) {
        return res.status(404).json({ error: 'Child not found' });
    }
    // Find caregiver by email
    const caregiver = await (0, database_1.db)('users')
        .where({ email: caregiverEmail, role: 'caregiver' })
        .first();
    if (!caregiver) {
        return res.status(404).json({ error: 'Caregiver not found' });
    }
    // Check if caregiver is already added
    const existingRelationship = await (0, database_1.db)('child_caregivers')
        .where({ child_id: childId, caregiver_id: caregiver.id })
        .first();
    if (existingRelationship) {
        return res.status(409).json({ error: 'Caregiver already added to this child' });
    }
    // Add caregiver relationship
    await (0, database_1.db)('child_caregivers').insert({
        child_id: childId,
        caregiver_id: caregiver.id
    });
    res.status(201).json({
        message: 'Caregiver added successfully',
        caregiver: {
            id: caregiver.id,
            firstName: caregiver.first_name,
            lastName: caregiver.last_name,
            email: caregiver.email
        }
    });
}));
// Remove caregiver from child (parent only)
router.delete('/caregivers/:childId/:caregiverId', auth_1.requireParent, (0, errorHandler_1.asyncHandler)(async (req, res) => {
    const { childId, caregiverId } = req.params;
    const parentId = req.user.userId;
    // Check if child exists and belongs to parent
    const child = await (0, database_1.db)('children')
        .where({ id: childId, parent_id: parentId })
        .first();
    if (!child) {
        return res.status(404).json({ error: 'Child not found' });
    }
    // Remove caregiver relationship
    const deletedCount = await (0, database_1.db)('child_caregivers')
        .where({ child_id: childId, caregiver_id: caregiverId })
        .del();
    if (deletedCount === 0) {
        return res.status(404).json({ error: 'Caregiver relationship not found' });
    }
    res.json({ message: 'Caregiver removed successfully' });
}));
// Update user profile
router.put('/profile', auth_1.requireAuth, [
    (0, express_validator_1.body)('firstName').optional().trim().isLength({ min: 1 }),
    (0, express_validator_1.body)('lastName').optional().trim().isLength({ min: 1 }),
    (0, express_validator_1.body)('profileImageURL').optional().isURL()
], (0, errorHandler_1.asyncHandler)(async (req, res) => {
    const errors = (0, express_validator_1.validationResult)(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }
    const { firstName, lastName, profileImageURL } = req.body;
    const userId = req.user.userId;
    const updateData = {};
    if (firstName)
        updateData.first_name = firstName;
    if (lastName)
        updateData.last_name = lastName;
    if (profileImageURL)
        updateData.profile_image_url = profileImageURL;
    if (Object.keys(updateData).length === 0) {
        return res.status(400).json({ error: 'No fields to update' });
    }
    updateData.updated_at = new Date();
    await (0, database_1.db)('users')
        .where({ id: userId })
        .update(updateData);
    // Get updated user
    const updatedUser = await (0, database_1.db)('users')
        .select('id', 'email', 'first_name', 'last_name', 'role', 'profile_image_url', 'created_at', 'updated_at')
        .where({ id: userId })
        .first();
    res.json({
        message: 'Profile updated successfully',
        user: updatedUser
    });
}));
// Get user's children
router.get('/children', auth_1.requireAuth, (0, errorHandler_1.asyncHandler)(async (req, res) => {
    const userId = req.user.userId;
    const userRole = req.user.role;
    let children;
    if (userRole === 'parent') {
        // Get children where user is parent
        children = await (0, database_1.db)('children')
            .where({ parent_id: userId })
            .select('*')
            .orderBy('first_name');
    }
    else {
        // Get children where user is caregiver
        children = await (0, database_1.db)('child_caregivers as cc')
            .join('children as c', 'cc.child_id', 'c.id')
            .select('c.*')
            .where({ 'cc.caregiver_id': userId })
            .orderBy('c.first_name');
    }
    res.json({ children });
}));
// Get user statistics
router.get('/stats', auth_1.requireAuth, (0, errorHandler_1.asyncHandler)(async (req, res) => {
    const userId = req.user.userId;
    const userRole = req.user.role;
    let stats = {};
    if (userRole === 'parent') {
        // Count children
        const childrenCount = await (0, database_1.db)('children')
            .where({ parent_id: userId })
            .count('* as count')
            .first();
        // Count caregivers
        const caregiversCount = await (0, database_1.db)('child_caregivers as cc')
            .join('children as c', 'cc.child_id', 'c.id')
            .where({ 'c.parent_id': userId })
            .count('cc.caregiver_id as count')
            .first();
        stats.childrenCount = parseInt(childrenCount?.count || '0');
        stats.caregiversCount = parseInt(caregiversCount?.count || '0');
    }
    else {
        // Count children under care
        const childrenCount = await (0, database_1.db)('child_caregivers')
            .where({ caregiver_id: userId })
            .count('child_id as count')
            .first();
        stats.childrenCount = parseInt(childrenCount?.count || '0');
    }
    // Count schedules for today
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    let schedulesQuery = (0, database_1.db)('schedules as s');
    if (userRole === 'parent') {
        schedulesQuery = schedulesQuery
            .join('children as c', 's.child_id', 'c.id')
            .where({ 'c.parent_id': userId });
    }
    else {
        schedulesQuery = schedulesQuery
            .join('child_caregivers as cc', 's.child_id', 'cc.child_id')
            .where({ 'cc.caregiver_id': userId });
    }
    const todaySchedules = await schedulesQuery
        .where('s.scheduled_time', '>=', today)
        .where('s.scheduled_time', '<', tomorrow)
        .count('* as count')
        .first();
    stats.todaySchedulesCount = parseInt(todaySchedules?.count || '0');
    res.json({ stats });
}));
exports.default = router;
