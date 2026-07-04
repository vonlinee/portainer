import { useEffect, useState } from 'react';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { vi } from 'vitest';

import {
  MonacoEditor,
  MonacoEditorHandle,
  MonacoEditorLanguage,
} from './MonacoEditor';

const editorState = {
  value: '',
  language: '',
  setValue: vi.fn((value: string) => {
    editorState.value = value;
  }),
  setLanguage: vi.fn((language: string) => {
    editorState.language = language;
  }),
  focus: vi.fn(),
};

vi.mock('@monaco-editor/react', () => ({
  Editor: function MockEditor(
    {
      value,
      language,
      onChange,
      onMount,
      wrapperProps,
    }: {
      value?: string;
      language?: string;
      onChange?: (value: string | undefined) => void;
      onMount?: (editor: unknown, monaco: unknown) => void;
      wrapperProps?: Record<string, unknown>;
    }
  ) {
    editorState.value = value || '';
    editorState.language = language || '';

    useEffect(() => {
      onMount?.(
        {
          getValue: () => editorState.value,
          setValue: editorState.setValue,
          getModel: () => ({
            getLanguageId: () => editorState.language,
          }),
          focus: editorState.focus,
        },
        {
          editor: {
            setModelLanguage: (_: unknown, language: string) =>
              editorState.setLanguage(language),
          },
        }
      );
    }, [onMount]);

    return (
      <textarea
        aria-label={(wrapperProps?.['aria-label'] as string) || 'Monaco Editor'}
        data-cy={wrapperProps?.['data-cy'] as string}
        value={value}
        onChange={(event) => onChange?.(event.target.value)}
      />
    );
  },
}));

beforeEach(() => {
  editorState.value = '';
  editorState.language = '';
  vi.clearAllMocks();
});

test('exposes value and language through a ref API', () => {
  const ref = { current: null as MonacoEditorHandle | null };

  render(
    <MonacoEditor
      ref={ref}
      value="services:"
      language="yaml"
      onChange={() => {}}
      data-cy="monaco-editor"
    />
  );

  expect(ref.current?.getValue()).toBe('services:');
  expect(ref.current?.getLanguage()).toBe('yaml');

  ref.current?.setValue('name: stack');
  ref.current?.setLanguage('json');
  ref.current?.focus();

  expect(editorState.setValue).toHaveBeenCalledWith('name: stack');
  expect(editorState.setLanguage).toHaveBeenCalledWith('json');
  expect(editorState.focus).toHaveBeenCalled();
});

test('passes text and language changes through controlled props', async () => {
  const onChange = vi.fn();

  function Wrapper() {
    const [language, setLanguage] = useState<MonacoEditorLanguage>('yaml');

    return (
      <>
        <MonacoEditor
          value=""
          language={language}
          onChange={onChange}
          onLanguageChange={setLanguage}
          data-cy="monaco-editor"
        />
        <button type="button" onClick={() => setLanguage('dockerfile')}>
          Dockerfile
        </button>
      </>
    );
  }

  render(<Wrapper />);

  await userEvent.click(screen.getByRole('textbox'));
  await userEvent.paste('services:');
  expect(onChange).toHaveBeenLastCalledWith('services:');

  await userEvent.click(screen.getByRole('button', { name: 'Dockerfile' }));
  expect(screen.getByRole('textbox')).toBeInTheDocument();
});
