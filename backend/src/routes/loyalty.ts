import { Router } from 'express';

const router = Router();

router.get('/health', (req, res) => {
  res.json({ success: true, service: 'loyalty' });
});

export default router;
