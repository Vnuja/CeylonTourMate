// CeylonTourMate — Error Handling Middleware
import { Request, Response, NextFunction } from 'express';

interface AppError extends Error {
  statusCode?: number;
  isOperational?: boolean;
}

export function errorMiddleware(
  err: AppError,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  console.error(`[Error] ${statusCode} ${req.method} ${req.path}:`, err.message);

  res.status(statusCode).json({
    error: {
      message,
      statusCode,
      path: req.path,
      timestamp: new Date().toISOString(),
    },
  });
}
