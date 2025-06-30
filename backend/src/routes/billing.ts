import { Router } from 'express';

const router = Router();

router.get('/health', (_req, res) => {
  res.json({ success: true, service: 'billing' });
});

export default router;
