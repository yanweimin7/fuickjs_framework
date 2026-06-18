import React, { useEffect } from 'react';
import ComponentStore from '../store/ComponentStore';
import { Container } from './Container';
import { Text } from './Text';
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

  // dialog presentation: DialogRoute already wraps content in a Dialog widget,
  // so we just render the component directly to avoid nested dialog padding.
  return <>{component}</>;
}
