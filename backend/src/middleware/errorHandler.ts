import { Request, Response, NextFunction } from 'express';
import { logger } from '@/utils/logger';

export interface AppError extends Error {
  statusCode?: number;
  isOperational?: boolean;
}

export const createError = (message: string, statusCode: number = 500): AppError => {
  const error: AppError = new Error(message);
  error.statusCode = statusCode;
  error.isOperational = true;
  return error;
};

export const errorHandler = (
  err: AppError,
  req: Request,
  res: Response,
  _next: NextFunction
): void => {
  let error = { ...err };
  error.message = err.message;

  // Log error
  logger.error('Error occurred:', {
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
  });

  // Default error
  let message = 'Internal Server Error';
  let statusCode = 500;

  // Mongoose bad ObjectId
  if (err.name === 'CastError') {
    message = 'Resource not found';
    statusCode = 404;
  }

  // Mongoose duplicate key
  if (err.name === 'MongoError' && (err as any).code === 11000) {
    message = 'Duplicate field value entered';
    statusCode = 400;
  }

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    message = Object.values((err as any).errors).map((val: any) => val.message).join(', ');
    statusCode = 400;
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    message = 'Invalid token';
    statusCode = 401;
  }

  if (err.name === 'TokenExpiredError') {
    message = 'Token expired';
    statusCode = 401;
  }

  // PostgreSQL errors
  if (err.name === 'error' && (err as any).code) {
    switch ((err as any).code) {
      case '23505': // unique_violation
        message = 'Duplicate entry';
        statusCode = 409;
        break;
      case '23503': // foreign_key_violation
        message = 'Referenced resource not found';
        statusCode = 400;
        break;
      case '23502': // not_null_violation
        message = 'Required field missing';
        statusCode = 400;
        break;
      case '22001': // string_data_right_truncation
        message = 'Data too long';
        statusCode = 400;
        break;
      default:
        message = 'Database error';
        statusCode = 500;
    }
  }

  // Use custom error message and status code if available
  if (err.isOperational && err.statusCode) {
    message = err.message;
    statusCode = err.statusCode;
  }

  res.status(statusCode).json({
    success: false,
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
    timestamp: new Date().toISOString(),
    path: req.path,
    method: req.method,
  });
};

export const asyncHandler = (fn: Function) => (req: Request, res: Response, next: NextFunction) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

export const notFound = (req: Request, res: Response, next: NextFunction): void => {
  const error = createError(`Not found - ${req.originalUrl}`, 404);
  next(error);
};
