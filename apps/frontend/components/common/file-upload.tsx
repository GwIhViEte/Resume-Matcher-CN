'use client';

import React, { useCallback, useMemo, useState } from 'react';
import {
	AlertCircleIcon,
	CheckCircle2Icon,
	Loader2Icon,
	PaperclipIcon,
	UploadIcon,
	XIcon,
} from 'lucide-react';
import { formatBytes, useFileUpload, type FileMetadata } from '@/hooks/use-file-upload';
import { Button } from '@/components/ui/button';
import { useI18n } from '@/components/common/language-provider';

const acceptedFileTypes = [
	'application/pdf',
	'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
];

const acceptString = acceptedFileTypes.join(',');
const API_RESUME_UPLOAD_URL = `${process.env.NEXT_PUBLIC_API_URL}/api/v1/resumes/upload`;

const PREMIUM_MODELS = ['gpt-4o'];

const SUCCESS_STATUS = 'success' as const;
const ERROR_STATUS = 'error' as const;

export default function FileUpload() {
	const { t, locale } = useI18n();
	const maxSize = 2 * 1024 * 1024; // 2MB

	const [uploadFeedback, setUploadFeedback] = useState<{
		type: typeof SUCCESS_STATUS | typeof ERROR_STATUS;
		message: string;
	} | null>(null);

	const [selectedModel, setSelectedModel] = useState('gpt-4.1-mini');
	const [token, setToken] = useState('');

	const isPremiumModel = useMemo(() => PREMIUM_MODELS.includes(selectedModel), [selectedModel]);

	const isUploadDisabled = useMemo(() => {
		if (isPremiumModel && !token.trim()) {
			return true;
		}
		return false;
	}, [isPremiumModel, token]);

	const uploadUrlWithParams = useMemo(() => {
		const params = new URLSearchParams({
			model: selectedModel,
			locale,
		});
		if (token) {
			params.set('token', token);
		}
		return `${API_RESUME_UPLOAD_URL}?${params.toString()}`;
	}, [selectedModel, token, locale]);

	const uploadHeaders = useMemo(() => ({ 'Accept-Language': locale }), [locale]);

	const mapUploadError = useCallback(
		(message: string) => {
			if (!message) {
				return t('upload.feedback.unknownError');
			}

			const tooLargeMatch = message.match(/^File "(.+)" exceeds the maximum size of (.+)\.$/);
			if (tooLargeMatch) {
				return t('upload.errors.tooLarge', {
					fileName: tooLargeMatch[1],
					maxSize: tooLargeMatch[2],
				});
			}

			const invalidFileMatch = message.match(/^Cannot upload "(.+)";.*$/);
			if (invalidFileMatch) {
				return t('upload.errors.invalidFileObject', {
					fileName: invalidFileMatch[1],
				});
			}

			if (message.includes('Upload URL is not configured')) {
				return t('upload.errors.missingEndpoint');
			}

			const failedMatch = message.match(/^Upload failed for (.+)\. Status: (\d+)/);
			if (failedMatch) {
				return t('upload.errors.failedWithStatus', {
					fileName: failedMatch[1],
					status: failedMatch[2],
				});
			}

			return message;
		},
		[t],
	);

	const [
		{ files, isDragging, errors: validationOrUploadErrors, isUploadingGlobal },
		{
			handleDragEnter,
			handleDragLeave,
			handleDragOver,
			handleDrop,
			openFileDialog,
			removeFile,
			getInputProps,
			clearErrors,
		},
	] = useFileUpload({
		maxSize,
		accept: acceptString,
		multiple: false,
		uploadUrl: uploadUrlWithParams,
		headers: uploadHeaders,
		onUploadSuccess: (uploadedFile, response) => {
			const data = response as Record<string, unknown> & { resume_id?: string };
			const resumeId = typeof data.resume_id === 'string' ? data.resume_id : undefined;
			const fileName = (uploadedFile.file as FileMetadata).name;

			if (!resumeId) {
				setUploadFeedback({
					type: ERROR_STATUS,
					message: t('upload.feedback.successMissingId'),
				});
				return;
			}

			setUploadFeedback({
				type: SUCCESS_STATUS,
				message: t('upload.feedback.success', { fileName }),
			});
			clearErrors();

			const params = new URLSearchParams({
				resume_id: resumeId,
				model: selectedModel,
			});
			if (token) {
				params.set('token', token);
			}
			window.location.href = `/jobs?${params.toString()}`;
		},
		onUploadError: (file, errorMsg) => {
			console.error('Upload failed:', file, errorMsg);
			setUploadFeedback({
				type: ERROR_STATUS,
				message: mapUploadError(errorMsg),
			});
		},
		onFilesChange: (currentFiles) => {
			if (currentFiles.length === 0) {
				setUploadFeedback(null);
			}
		},
	});

	const currentFile = files[0];

	const handleRemoveFile = (id: string) => {
		removeFile(id);
		setUploadFeedback(null);
	};

	const mappedErrors = useMemo(() => {
		const rawErrors = uploadFeedback?.type === ERROR_STATUS ? [uploadFeedback.message] : validationOrUploadErrors;
		return rawErrors.map(mapUploadError);
	}, [uploadFeedback, validationOrUploadErrors, mapUploadError]);

	return (
		<div className="flex w-full flex-col gap-4 rounded-lg">
			<div className="w-full">
				<label htmlFor="model-select" className="block text-sm font-medium text-gray-300 mb-2">
					{t('upload.labels.selectModel')}
				</label>
				<select
					id="model-select"
					value={selectedModel}
					onChange={(event) => setSelectedModel(event.target.value)}
					className="w-full p-2 rounded-md bg-gray-800/50 border border-gray-700 text-white focus:ring-blue-500 focus:border-blue-500"
				>
					<option value="gpt-5-nano">GPT-5-nano</option>
					<option value="gpt-4.1-mini">GPT-4.1-mini</option>
					<option value="gpt-5-mini">GPT-5-mini</option>
					<option value="gpt-5">GPT-5</option>
					<option value="gpt-4o">GPT-4o</option>
				</select>
			</div>

			{isPremiumModel && (
				<div className="w-full">
					<label htmlFor="token-input" className="block text-sm font-medium text-gray-300 mb-2">
						{t('upload.labels.enterToken')}
					</label>
					<input
						id="token-input"
						type="text"
						value={token}
						onChange={(event) => setToken(event.target.value)}
						placeholder={t('upload.labels.promptToken')}
						className="w-full p-2 rounded-md bg-gray-800/50 border border-gray-700 text-white focus:ring-blue-500 focus:border-blue-500"
					/>
				</div>
			)}

			<div
				role="button"
				tabIndex={0}
				onClick={
					!isUploadingGlobal && !isUploadDisabled && !currentFile
						? () => openFileDialog()
						: undefined
				}
				onKeyDown={(event) => {
					if ((event.key === 'Enter' || event.key === ' ') && !currentFile && !isUploadingGlobal && !isUploadDisabled) {
						event.preventDefault();
						openFileDialog();
					}
				}}
				onDragEnter={!isUploadingGlobal && !isUploadDisabled ? handleDragEnter : undefined}
				onDragLeave={!isUploadingGlobal && !isUploadDisabled ? handleDragLeave : undefined}
				onDragOver={!isUploadingGlobal && !isUploadDisabled ? handleDragOver : undefined}
				onDrop={!isUploadingGlobal && !isUploadDisabled ? handleDrop : undefined}
				data-dragging={isDragging || undefined}
				className={`relative rounded-xl border-2 border-dashed transition-all duration-300 ease-in-out ${
					currentFile || isUploadingGlobal || isUploadDisabled
						? 'cursor-not-allowed opacity-70 border-gray-700'
						: 'cursor-pointer border-gray-600 hover:border-primary hover:bg-gray-900/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 focus-visible:ring-offset-background'
				}
				${
					isDragging && !isUploadingGlobal && !isUploadDisabled
						? 'border-primary bg-primary/10'
						: 'bg-gray-900/50'
				}`}
				aria-disabled={Boolean(currentFile) || isUploadingGlobal || isUploadDisabled}
				aria-label={currentFile ? t('upload.labels.fileSelected') : t('upload.labels.fileArea')}
			>
				<div className="flex min-h-48 w-full flex-col items-center justify-center p-6 text-center">
					<input {...getInputProps()} />
					{isUploadingGlobal ? (
						<>
							<Loader2Icon className="mb-4 size-10 animate-spin text-primary" />
							<p className="text-lg font-semibold text-white">{t('common.status.uploading')}</p>
							<p className="text-sm text-muted-foreground">{t('upload.labels.fileArea')}</p>
						</>
					) : (
						<>
							<div className="mb-4 flex size-12 items-center justify-center rounded-full border border-gray-700 bg-gray-800 text-gray-400">
								<UploadIcon className="size-6" />
							</div>
							<p className="mb-1 text-lg font-semibold text-white">
								{isUploadDisabled ? t('upload.labels.enterToken') : currentFile ? t('upload.labels.fileReady') : t('upload.labels.sectionTitle')}
							</p>
							<p className="text-sm text-muted-foreground">
								{currentFile
									? currentFile.file.name
									: t('upload.labels.fileSelector', { size: formatBytes(maxSize) })}
							</p>
						</>
					)}
				</div>
			</div>

			{mappedErrors.length > 0 && !isUploadingGlobal && (!uploadFeedback || uploadFeedback.type === ERROR_STATUS) && (
				<div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive" role="alert">
					<div className="flex items-start gap-2">
						<AlertCircleIcon className="mt-0.5 size-5 shrink-0" />
						<div>
							<p className="font-semibold">{t('common.status.failed')}</p>
							{mappedErrors.map((error, index) => (
								<p key={index}>{error}</p>
							))}
						</div>
					</div>
				</div>
			)}

			{uploadFeedback?.type === SUCCESS_STATUS && !isUploadingGlobal && (
				<div className="rounded-md border border-green-500/50 bg-green-500/10 p-3 text-sm text-green-600" role="status">
					<div className="flex items-start gap-2">
						<CheckCircle2Icon className="mt-0.5 size-5 shrink-0" />
						<div>
							<p className="font-semibold">{t('common.status.success')}</p>
							<p>{uploadFeedback.message}</p>
						</div>
					</div>
				</div>
			)}

			{currentFile && !isUploadingGlobal && (
				<div className="rounded-xl border border-gray-700 bg-background/60 p-4">
					<div className="flex items-center justify-between gap-3">
						<div className="flex min-w-0 items-center gap-3">
							<PaperclipIcon className="size-5 shrink-0 text-muted-foreground" />
							<div className="min-w-0 flex-1">
								<p className="truncate text-sm font-medium text-white">{currentFile.file.name}</p>
								<p className="text-xs text-muted-foreground">
									{formatBytes(currentFile.file.size)} -{' '}
									{(currentFile.file as FileMetadata).uploaded === true
										? t('upload.status.uploaded')
										: (currentFile.file as FileMetadata).uploadError
											? t('upload.status.failed')
											: t('upload.status.pending')}
								</p>
							</div>
						</div>
						<Button
							size="icon"
							variant="ghost"
							className="size-8 shrink-0 text-muted-foreground hover:text-white"
							onClick={() => handleRemoveFile(currentFile.id)}
							aria-label={t('upload.labels.fileSelected')}
							disabled={isUploadingGlobal}
						>
							<XIcon className="size-5" />
						</Button>
					</div>
				</div>
			)}
		</div>
	);
}
