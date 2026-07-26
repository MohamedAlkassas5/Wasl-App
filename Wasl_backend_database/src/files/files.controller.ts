import {
  Controller,
  ForbiddenException,
  Get,
  Param,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';

import { FilesService } from './files.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../auth/current-user';

/**
 * Authenticated access to `uploads/`.
 *
 * These files used to be served by `express.static`, i.e. readable by anyone who
 * could guess a URL — national ID scans, selfies and payment-proof screenshots
 * included. Every read now costs a valid token plus an ownership check.
 */
@Controller('uploads')
@UseGuards(JwtAuthGuard)
export class FilesController {
  constructor(private readonly filesService: FilesService) {}

  // uploads/<file> — registration documents (ID front/back, selfie, vehicle, logo)
  @Get(':filename')
  async getRootFile(
    @CurrentUser() user: AuthUser,
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    return this.send(user, filename, undefined, res);
  }

  // uploads/orders|invoices|payments/<file>
  @Get(':folder/:filename')
  async getFolderFile(
    @CurrentUser() user: AuthUser,
    @Param('folder') folder: string,
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    return this.send(user, filename, folder, res);
  }

  private async send(
    user: AuthUser,
    filename: string,
    folder: string | undefined,
    res: Response,
  ) {
    const { relativePath } = await this.filesService.resolveUpload(
      filename,
      folder,
    );

    if (!(await this.filesService.canRead(user, relativePath))) {
      throw new ForbiddenException('عفواً، لا تملك صلاحية عرض هذا الملف');
    }

    // Personal documents must never sit in a shared/CDN cache.
    res.setHeader('Cache-Control', 'private, no-store');

    // Local backend → sendFile (Content-Type by extension, range support).
    // Remote backend → pipe the object's stream.
    const plan = this.filesService.servePlan(relativePath);
    if (plan.kind === 'local') {
      res.sendFile(plan.localPath);
    } else {
      plan.stream.pipe(res);
    }
  }
}
