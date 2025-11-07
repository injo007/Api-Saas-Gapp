

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
    if (!recipientsText.trim()) {
        newErrors.recipientsText = 'Recipients list cannot be empty.';
    } else {
        const lines = recipientsText.trim().split('\n');
        const invalidLines = lines.filter(line => !/^\s*\S+@\S+\.\S+\s*(,.*)?\s*$/.test(line));
        if (invalidLines.length > 0) {
            newErrors.recipientsText = `Invalid recipient format on ${invalidLines.length} line(s). Expected: email@example.com,Name`;
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
        const newCampaign: CampaignCreatePayload = {
            name,
            from_name: fromName,
            from_email: fromEmail,
            subject,
            html_body: htmlBody,
            recipients_csv: recipientsText
        };
        await onSaveCampaign(newCampaign);
        addToast({ message: `Campaign "${name}" created successfully as a draft!`, type: 'success' });
        // No need to reset form here, onSaveCampaign will navigate back which unmounts this component
    } catch (err) {
        addToast({ message: `Failed to create campaign: ${err instanceof Error ? err.message : 'Unknown error'}`, type: 'error' });
        console.error(err);
    } finally {
        setIsSubmitting(false);
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
                    <Textarea
                        label="Recipients (CSV)"
                        id="recipients"
                        value={recipientsText}
                        onChange={e => {setRecipientsText(e.target.value); setErrors(prev => ({...prev, recipientsText: undefined}));}}
                        rows={10}
                        placeholder="email@example.com,John Doe\nanother@example.com,Jane Smith"
                        required
                        helperText="One recipient per line in `email,name` format."
                        error={errors.recipientsText}
                    />
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