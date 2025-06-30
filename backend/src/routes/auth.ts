import { Router } from 'express';

const router = Router();

// Placeholder auth routes
router.get('/health', (req, res) => {
  res.json({ success: true, service: 'auth' });
});

export default router;
