import { Request, Response, NextFunction } from 'express';
declare global {
    namespace Express {
        interface Request {
            user?: {
                userId: string;
                email: string;
                role: string;
            };
        }
    }
}
export declare const authMiddleware: (req: Request, res: Response, next: NextFunction) => Response<any, Record<string, any>>;
export declare const optionalAuthMiddleware: (req: Request, res: Response, next: NextFunction) => void;
export declare const requireRole: (allowedRoles: string[]) => (req: Request, res: Response, next: NextFunction) => Response<any, Record<string, any>>;
export declare const requireParent: (req: Request, res: Response, next: NextFunction) => Response<any, Record<string, any>>;
export declare const requireCaregiver: (req: Request, res: Response, next: NextFunction) => Response<any, Record<string, any>>;
export declare const requireAuth: (req: Request, res: Response, next: NextFunction) => Response<any, Record<string, any>>;
//# sourceMappingURL=auth.d.ts.map