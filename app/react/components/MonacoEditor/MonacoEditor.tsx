import {
  AriaAttributes,
  ComponentProps,
  forwardRef,
  useCallback,
  useImperativeHandle,
  useRef,
  useState,
} from 'react';
import { Editor } from '@monaco-editor/react';
import type { Monaco, OnMount } from '@monaco-editor/react';
import type { editor } from 'monaco-editor';
import clsx from 'clsx';

import { AutomationTestingProps } from '@/types';

export type MonacoEditorLanguage =
  | 'yaml'
  | 'json'
  | 'dockerfile'
  | 'shell'
  | 'plaintext';

export interface MonacoEditorHandle {
  getValue(): string;
  setValue(value: string): void;
  getLanguage(): MonacoEditorLanguage;
  setLanguage(language: MonacoEditorLanguage): void;
  focus(): void;
}

interface Props
  extends AutomationTestingProps,
    Pick<AriaAttributes, 'aria-label'> {
  value: string;
  language: MonacoEditorLanguage;
  onChange?: (value: string) => void;
  onLanguageChange?: (language: MonacoEditorLanguage) => void;
  readonly?: boolean;
  height?: string;
  id?: string;
  className?: string;
  options?: editor.IStandaloneEditorConstructionOptions;
}

const defaultOptions: editor.IStandaloneEditorConstructionOptions = {
  minimap: { enabled: false },
  scrollBeyondLastLine: false,
  wordWrap: 'on',
  automaticLayout: true,
  tabSize: 2,
};

export const MonacoEditor = forwardRef<MonacoEditorHandle, Props>(
  function MonacoEditor(
    {
      value,
      language,
      onChange,
      onLanguageChange,
      readonly,
      height = '500px',
      id,
      className,
      options,
      'data-cy': dataCy,
      'aria-label': ariaLabel,
    },
    ref
  ) {
    const editorRef = useRef<editor.IStandaloneCodeEditor | null>(null);
    const monacoRef = useRef<Monaco | null>(null);
    const [currentLanguage, setCurrentLanguage] =
      useState<MonacoEditorLanguage>(language);

    const handleMount = useCallback<OnMount>((editorInstance, monaco) => {
      editorRef.current = editorInstance;
      monacoRef.current = monaco;
    }, []);

    useImperativeHandle(
      ref,
      () => ({
        getValue() {
          return editorRef.current?.getValue() ?? value;
        },
        setValue(nextValue) {
          editorRef.current?.setValue(nextValue);
        },
        getLanguage() {
          const modelLanguage = editorRef.current?.getModel()?.getLanguageId();
          return (modelLanguage || currentLanguage) as MonacoEditorLanguage;
        },
        setLanguage(nextLanguage) {
          const model = editorRef.current?.getModel();
          if (model) {
            monacoRef.current?.editor.setModelLanguage(model, nextLanguage);
          }
          setCurrentLanguage(nextLanguage);
          onLanguageChange?.(nextLanguage);
        },
        focus() {
          editorRef.current?.focus();
        },
      }),
      [currentLanguage, onLanguageChange, value]
    );

    return (
      <div
        className={clsx(
          'overflow-hidden rounded-lg border border-solid border-gray-5 th-highcontrast:border-gray-2 th-dark:border-gray-7',
          className
        )}
      >
        <Editor
          value={value}
          language={language}
          onChange={(nextValue) => onChange?.(nextValue || '')}
          onMount={handleMount}
          height={height}
          theme="light"
          options={{
            ...defaultOptions,
            ...options,
            readOnly: readonly || options?.readOnly,
          }}
          wrapperProps={{
            id,
            'data-cy': dataCy,
            'aria-label': ariaLabel || 'Monaco Editor',
          }}
        />
      </div>
    );
  }
);

export type MonacoEditorProps = ComponentProps<typeof MonacoEditor>;
