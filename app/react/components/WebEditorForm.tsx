import { ReactNode, PropsWithChildren, useMemo } from 'react';
import { JSONSchema7 } from 'json-schema';

import { CopyButton } from '@@/buttons/CopyButton';
import {
  MonacoEditor,
  MonacoEditorLanguage,
  MonacoEditorProps,
} from '@@/MonacoEditor';

import { FormSectionTitle } from './form-components/FormSectionTitle';
import { FormError } from './form-components/FormError';
import { usePreventFormExit } from './form-components/usePreventFormExit';
import { confirmWebEditorDiscard } from './modals/confirm';
import { ShortcutsTooltip } from './CodeEditor/ShortcutsTooltip';
import { TextTip } from './Tip/TextTip';

type EditorProps = Omit<MonacoEditorProps, 'language'> & {
  type?: MonacoEditorLanguage;
  language?: MonacoEditorLanguage;
  textTip?: string;
  showToolbar?: boolean;
  fileName?: string;
  versions?: number[];
  onVersionChange?: (version: number) => void;
};

interface Props extends EditorProps {
  titleContent?: ReactNode;
  hideTitle?: boolean;
  error?: string;
  schema?: JSONSchema7;
}

export function WebEditorForm({
  id,
  titleContent = 'Web editor',
  hideTitle,
  children,
  error,
  textTip,
  type = 'yaml',
  language,
  showToolbar = true,
  value,
  versions,
  onVersionChange,
  ...props
}: PropsWithChildren<Props>) {
  const editorLanguage = language || type;
  const editorValue = value || '';
  void versions;
  void onVersionChange;
  const editorId = id || 'web-editor';

  return (
    <div>
      <div className="web-editor overflow-x-hidden">
        {!hideTitle && (
          <DefaultTitle id={editorId}>{titleContent ?? null}</DefaultTitle>
        )}
        {children && (
          <div className="form-group text-muted small">
            <div className="col-sm-12 col-lg-12">{children}</div>
          </div>
        )}

        {error && <FormError>{error}</FormError>}

        <div className="form-group">
          <div className="col-sm-12 col-lg-12">
            {showToolbar && (
              <div className="mb-2 flex items-center justify-between">
                {!!textTip && <TextTip color="blue">{textTip}</TextTip>}
                <CopyButton
                  data-cy={`copy-code-button-${editorId}`}
                  fadeDelay={2500}
                  copyText={editorValue}
                  color="link"
                  className="!pr-0 !text-sm !font-medium hover:no-underline focus:no-underline"
                  indicatorPosition="left"
                >
                  Copy
                </CopyButton>
              </div>
            )}
            <MonacoEditor
              id={editorId}
              value={editorValue}
              language={editorLanguage}
              // eslint-disable-next-line react/jsx-props-no-spreading
              {...props}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

function DefaultTitle({ id, children }: { id: string; children?: ReactNode }) {
  return (
    <FormSectionTitle htmlFor={id}>
      {children}
      <ShortcutsTooltip />
    </FormSectionTitle>
  );
}

export function usePreventExit(
  initialValue: string,
  value: string,
  check: boolean
) {
  const isChanged = useMemo(
    () => cleanText(initialValue) !== cleanText(value),
    [initialValue, value]
  );

  usePreventFormExit(() => isChanged, check, confirmWebEditorDiscard);
}

function cleanText(value: string) {
  return value.replace(/(\r\n|\n|\r)/gm, '');
}
