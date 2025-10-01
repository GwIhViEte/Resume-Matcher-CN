'use client';

import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { XIcon, ClipboardPasteIcon } from 'lucide-react';
import { useI18n } from '@/components/common/language-provider';

interface PasteJobDescriptionProps {
	onClose: () => void;
	onPaste: (text: string) => void;
}

export default function PasteJobDescription({ onClose, onPaste }: PasteJobDescriptionProps) {
	const [jobDescription, setJobDescription] = useState('');
	const [error, setError] = useState<string | null>(null);
	const { t } = useI18n();

	const handlePaste = () => {
		if (!jobDescription.trim()) {
			setError(t('jobModal.errorRequired'));
			return;
		}
		setError(null);
		onPaste(jobDescription);
		onClose();
	};

	return (
		<div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
			<div className="relative w-full max-w-2xl rounded-xl bg-gray-800 p-6 shadow-xl">
				<div className="flex items-center justify-between pb-4 border-b border-gray-700">
					<h3 className="text-lg font-semibold text-white">{t('jobModal.title')}</h3>
					<Button
						size="icon"
						variant="ghost"
						className="text-muted-foreground/80 hover:text-foreground -me-2 size-9 hover:bg-transparent"
						onClick={onClose}
						aria-label={t('jobModal.aria.close')}
					>
						<XIcon className="size-5" aria-hidden="true" />
					</Button>
				</div>

				<div className="py-6">
					<div className="flex flex-col items-center justify-center text-center mb-4">
						<div
							className="bg-white mb-3 flex size-12 shrink-0 items-center justify-center rounded-full border"
							aria-hidden="true"
						>
							<ClipboardPasteIcon className="size-5 opacity-60" />
						</div>
						<p className="mb-2 text-lg font-semibold text-white">{t('jobModal.title')}</p>
						<p className="text-muted-foreground text-sm">{t('jobModal.description')}</p>
					</div>

					<Textarea
						value={jobDescription}
						onChange={(event) => {
							setJobDescription(event.target.value);
							if (error) setError(null);
						}}
						placeholder={t('jobModal.placeholder')}
						className="w-full min-h-[200px] rounded-md border-gray-600 bg-gray-700 p-3 text-white focus:ring-blue-500 focus:border-blue-500"
						aria-label={t('jobModal.aria.textarea')}
					/>
					{error && (
						<p className="text-destructive mt-2 text-xs" role="alert">
							{error}
						</p>
					)}
				</div>

				<div className="flex justify-end gap-3 pt-4 border-t border-gray-700">
					<Button
						variant="outline"
						onClick={onClose}
						className="text-white border-gray-600 hover:bg-gray-700"
					>
						{t('jobModal.cancel')}
					</Button>
					<Button
						onClick={handlePaste}
						className="bg-blue-600 hover:bg-blue-700 text-white"
					>
						{t('jobModal.save')}
					</Button>
				</div>
			</div>
		</div>
	);
}
