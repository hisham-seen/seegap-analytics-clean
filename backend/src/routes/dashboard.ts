import { Router } from 'express';

const router = Router();

router.get('/health', (req, res) => {
  res.json({ success: true, service: 'dashboard' });
});

export default router;
