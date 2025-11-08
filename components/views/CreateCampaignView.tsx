

import React, { useState } from 'react';
import { CampaignCreatePayload } from '../../types';
import Button from '../ui/Button';
import Card, { CardContent } from '../ui/Card';
import Input from '../ui/Input';
import Textarea from '../ui/Textarea'; // Using the new Textarea component
import ChevronLeftIcon from '../icons/ChevronLeftIcon';
import { useToast } from '../../contexts/ToastContext';

interface CreateCampaignViewProps {
  onBack: () => void;
  onSaveCampaign: (campaign: CampaignCreatePayload) => Promise<void>;
}

const CreateCampaignView: React.FC<CreateCampaignViewProps> = ({ onBack, onSaveCampaign }) => {
  const [name, setName] = useState('');
  const [fromName, setFromName] = useState('');
  const [fromEmail, setFromEmail] = useState('');
  const [subject, setSubject] = useState('');
  const [htmlBody, setHtmlBody] = useState('<h1>Your Email Title</h1>\n<p>This is a sample email body.</p>');
  const [recipientsText, setRecipientsText] = useState('');
  const [csvFile, setCsvFile] = useState<File | null>(null);
  const [uploadMode, setUploadMode] = useState<'text' | 'file'>('text');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errors, setErrors] = useState<{ [key: string]: string | undefined }>({});

  const { addToast } = useToast();

  const validateForm = () => {
    const newErrors: typeof errors = {};
    if (!name.trim()) newErrors.name = 'Campaign Name is required.';
    if (!fromName.trim()) newErrors.fromName = 'From Name is required.';
    if (!fromEmail.trim()) {
      newErrors.fromEmail = 'From Email is required.';
    } else if (!/\S+@\S+\.\S+/.test(fromEmail)) {
      newErrors.fromEmail = 'Invalid email format.';
    }
    if (!subject.trim()) newErrors.subject = 'Subject is required.';
    if (!htmlBody.trim()) newErrors.htmlBody = 'HTML Body cannot be empty.';
    if (uploadMode === 'text') {
        if (!recipientsText.trim()) {
            newErrors.recipientsText = 'Recipients list cannot be empty.';
        } else {
            const lines = recipientsText.trim().split('\\n');
            const invalidLines = lines.filter(line => !/^\\s*\\S+@\\S+\\.\\S+\\s*(,.*)?\\s*$/.test(line));
            if (invalidLines.length > 0) {
                newErrors.recipientsText = `Invalid recipient format on ${invalidLines.length} line(s). Expected: email@example.com,Name`;
            }
        }
    } else {
        if (!csvFile) {
            newErrors.csvFile = 'Please select a CSV file.';
        }
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };
  
  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validateForm()) {
        addToast({ message: 'Please correct the errors in the form.', type: 'error' });
        return;
    }

    setIsSubmitting(true);
    try {
        let recipients_csv = '';
        
        if (uploadMode === 'file' && csvFile) {
            // Read CSV file content
            const fileContent = await new Promise<string>((resolve, reject) => {
                const reader = new FileReader();
                reader.onload = () => resolve(reader.result as string);
                reader.onerror = reject;
                reader.readAsText(csvFile);
            });
            recipients_csv = fileContent;
        } else {
            recipients_csv = recipientsText;
        }

        const newCampaign: CampaignCreatePayload = {
            name,
            from_name: fromName,
            from_email: fromEmail,
            subject,
            html_body: htmlBody,
            recipients_csv
        };
        await onSaveCampaign(newCampaign);
        addToast({ message: `Campaign \"${name}\" created successfully as a draft!`, type: 'success' });
        // No need to reset form here, onSaveCampaign will navigate back which unmounts this component
    } catch (err) {
        addToast({ message: `Failed to create campaign: ${err instanceof Error ? err.message : 'Unknown error'}`, type: 'error' });
        console.error(err);
    } finally {
        setIsSubmitting(false);
    }
  };

  const handleCsvFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setCsvFile(e.target.files[0]);
      setErrors(prev => ({ ...prev, csvFile: undefined }));
    } else {
      setCsvFile(null);
    }
  };

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6">
      <div className="flex items-center space-x-3">
        <Button variant="secondary" onClick={onBack} className="p-2 !rounded-full">
            <ChevronLeftIcon className="w-5 h-5"/>
        </Button>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Create New Campaign</h1>
      </div>
      
      <form onSubmit={handleSave}>
        <Card>
            <CardContent className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-4">
                    <Input 
                        label="Campaign Name" 
                        id="campaignName" 
                        value={name} 
                        onChange={e => {setName(e.target.value); setErrors(prev => ({...prev, name: undefined}));}} 
                        placeholder="e.g., Q4 Product Update" 
                        required 
                        error={errors.name}
                    />
                    <Input 
                        label="From Name" 
                        id="fromName" 
                        value={fromName} 
                        onChange={e => {setFromName(e.target.value); setErrors(prev => ({...prev, fromName: undefined}));}} 
                        placeholder="Your Company" 
                        required 
                        error={errors.fromName}
                    />
                    <Input 
                        label="From Email" 
                        id="fromEmail" 
                        type="email" 
                        value={fromEmail} 
                        onChange={e => {setFromEmail(e.target.value); setErrors(prev => ({...prev, fromEmail: undefined}));}} 
                        placeholder="newsletter@yourcompany.com" 
                        required 
                        error={errors.fromEmail}
                    />
                    <Input 
                        label="Subject" 
                        id="subject" 
                        value={subject} 
                        onChange={e => {setSubject(e.target.value); setErrors(prev => ({...prev, subject: undefined}));}} 
                        placeholder="Exciting news about..." 
                        required 
                        error={errors.subject}
                    />
                </div>
                <div className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">Recipients Data</label>
                        
                        {/* Upload Mode Toggle */}
                        <div className="flex space-x-4 mb-4">
                            <label className="flex items-center">
                                <input
                                    type="radio"
                                    name="uploadMode"
                                    value="text"
                                    checked={uploadMode === 'text'}
                                    onChange={() => setUploadMode('text')}
                                    className="mr-2"
                                />
                                <span className="text-sm">Manual Input</span>
                            </label>
                            <label className="flex items-center">
                                <input
                                    type="radio"
                                    name="uploadMode"
                                    value="file"
                                    checked={uploadMode === 'file'}
                                    onChange={() => setUploadMode('file')}
                                    className="mr-2"
                                />
                                <span className="text-sm">CSV File Upload</span>
                            </label>
                        </div>

                        {/* Manual Text Input */}
                        {uploadMode === 'text' && (
                            <Textarea
                                label=""
                                id="recipients"
                                value={recipientsText}
                                onChange={e => {setRecipientsText(e.target.value); setErrors(prev => ({...prev, recipientsText: undefined}));}}
                                rows={10}
                                placeholder="email@example.com,John Doe&#10;another@example.com,Jane Smith"
                                required
                                helperText="One recipient per line in email,name format."
                                error={errors.recipientsText}
                            />
                        )}

                        {/* CSV File Upload */}
                        {uploadMode === 'file' && (
                            <div>
                                <input
                                    type="file"
                                    accept=".csv,.txt"
                                    onChange={handleCsvFileChange}
                                    className={`block w-full text-sm text-gray-900 border ${errors.csvFile ? 'border-red-500' : 'border-gray-300'} rounded-lg cursor-pointer bg-gray-50 dark:text-gray-400 focus:outline-none dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-primary-50 file:text-primary-700 hover:file:bg-primary-100`}
                                />
                                {errors.csvFile && <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.csvFile}</p>}
                                <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                                    Upload a CSV file with format: email,name (one per line)
                                </p>
                                {csvFile && (
                                    <p className="mt-2 text-sm text-green-600 dark:text-green-400">
                                        ✓ Selected: {csvFile.name} ({Math.round(csvFile.size / 1024)} KB)
                                    </p>
                                )}
                            </div>
                        )}
                    </div>
                </div>
                <div className="md:col-span-2 space-y-4">
                    <Textarea
                        label="HTML Body"
                        id="htmlBody"
                        value={htmlBody}
                        onChange={e => {setHtmlBody(e.target.value); setErrors(prev => ({...prev, htmlBody: undefined}));}}
                        rows={16}
                        className="font-mono text-sm"
                        placeholder="<html>...</html>"
                        required
                        helperText="Paste your full HTML email content here. For a production app, this would typically be a rich HTML editor."
                        error={errors.htmlBody}
                    />
                </div>
            </CardContent>
             <div className="p-4 bg-gray-50 dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700 flex justify-end space-x-2">
                <Button variant="secondary" type="button" onClick={onBack} disabled={isSubmitting}>Cancel</Button>
                <Button type="submit" disabled={isSubmitting}>
                    {isSubmitting ? (
                        <span className="flex items-center">
                            <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                            </svg>
                            Saving...
                        </span>
                    ) : (
                        "Save as Draft"
                    )}
                </Button>
            </div>
        </Card>
      </form>
    </div>
  );
};

export default CreateCampaignView;