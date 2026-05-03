import React, { useEffect } from 'react';
import ComponentStore from '../store/ComponentStore';
import { Container } from './Container';
import { Text } from './Text';
import { Dialog } from './Dialog';
import { Column } from './Column';

interface GenericPageProps {
  componentId: string;
  presentation?: string;
}

export function GenericPage(props: GenericPageProps) {
  const { componentId, presentation } = props;
  const component = ComponentStore.getInstance().get(componentId);

  useEffect(() => {
    return () => {
      if (componentId) {
        ComponentStore.getInstance().remove(componentId);
      }
    };
  }, [componentId]);

  if (!component) {
    return (
        <Container alignment="center">
            <Text text="Content not found" />
        </Container>
    );
  }

  if (presentation === 'bottomSheet') {
    return (
      <Column mainAxisSize="min" padding={{ top: 12 }}>
        {component}
      </Column>
    );
  }

  return (
    <Dialog elevation={8} borderRadius={28}>
      {component}
    </Dialog>
  );
}
