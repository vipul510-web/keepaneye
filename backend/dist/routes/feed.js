"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const database_1 = require("../config/database");
const auth_1 = require("../middleware/auth");
const express_validator_1 = require("express-validator");
const router = express_1.default.Router();
// Helper: RBAC check - ensure requester can access child
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
// Get feed items for a child
router.get('/', auth_1.authMiddleware, async (req, res) => {
    try {
        const { childId } = req.query;
        const userId = req.user?.userId;
        const userRole = req.user?.role;
        if (!childId) {
            return res.status(400).json({ error: 'Child ID is required' });
        }
        // Verify user has access to this child
        const allowed = await canAccessChild(userId, userRole, childId);
        if (!allowed) {
            return res.status(403).json({ error: 'Access denied to this child' });
        }
        const feedItems = await (0, database_1.db)('feed_items')
            .where('child_id', childId)
            .orderBy('created_at', 'desc');
        res.json({ feedItems });
    }
    catch (error) {
        console.error('Error fetching feed items:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Create a new feed item
router.post('/', auth_1.authMiddleware, [
    (0, express_validator_1.body)('childId').notEmpty().withMessage('Child ID is required'),
    (0, express_validator_1.body)('title').notEmpty().withMessage('Title is required'),
    (0, express_validator_1.body)('content').notEmpty().withMessage('Content is required'),
    (0, express_validator_1.body)('contentType').isIn(['note', 'photo', 'video']).withMessage('Invalid content type'),
], async (req, res) => {
    try {
        const errors = (0, express_validator_1.validationResult)(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }
        const { childId, title, content, contentType, mediaURLs = [], isPinned = false } = req.body;
        const userId = req.user?.userId;
        const userRole = req.user?.role;
        // Verify user has access to this child
        const allowed = await canAccessChild(userId, userRole, childId);
        if (!allowed) {
            return res.status(403).json({ error: 'Access denied to this child' });
        }
        const [feedItem] = await (0, database_1.db)('feed_items')
            .insert({
            child_id: childId,
            title,
            content,
            content_type: contentType,
            media_urls: JSON.stringify(mediaURLs),
            created_by: userId,
            is_pinned: isPinned,
            created_at: new Date(),
            updated_at: new Date()
        })
            .returning('*');
        res.status(201).json({ feedItem });
    }
    catch (error) {
        console.error('Error creating feed item:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Update a feed item
router.put('/:id', auth_1.authMiddleware, [
    (0, express_validator_1.body)('title').optional().notEmpty().withMessage('Title cannot be empty'),
    (0, express_validator_1.body)('content').optional().notEmpty().withMessage('Content cannot be empty'),
], async (req, res) => {
    try {
        const errors = (0, express_validator_1.validationResult)(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }
        const { id } = req.params;
        const { title, content, mediaURLs, isPinned } = req.body;
        const userId = req.user?.userId;
        // Verify user owns this feed item
        const existingItem = await (0, database_1.db)('feed_items')
            .where('id', id)
            .where('created_by', userId)
            .first();
        if (!existingItem) {
            return res.status(404).json({ error: 'Feed item not found' });
        }
        const updateData = { updated_at: new Date() };
        if (title !== undefined)
            updateData.title = title;
        if (content !== undefined)
            updateData.content = content;
        if (mediaURLs !== undefined)
            updateData.media_urls = JSON.stringify(mediaURLs);
        if (isPinned !== undefined)
            updateData.is_pinned = isPinned;
        const [updatedItem] = await (0, database_1.db)('feed_items')
            .where('id', id)
            .update(updateData)
            .returning('*');
        res.json({ feedItem: updatedItem });
    }
    catch (error) {
        console.error('Error updating feed item:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Delete a feed item
router.delete('/:id', auth_1.authMiddleware, async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user?.userId;
        // Verify user owns this feed item
        const existingItem = await (0, database_1.db)('feed_items')
            .where('id', id)
            .where('created_by', userId)
            .first();
        if (!existingItem) {
            return res.status(404).json({ error: 'Feed item not found' });
        }
        await (0, database_1.db)('feed_items')
            .where('id', id)
            .del();
        res.json({ message: 'Feed item deleted successfully' });
    }
    catch (error) {
        console.error('Error deleting feed item:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
exports.default = router;
