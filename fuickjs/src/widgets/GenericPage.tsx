import React, { useEffect } from 'react';
import ComponentStore from '../services/ComponentStore';
import { Container } from './Container';
import { Text } from './Text';

interface GenericPageProps {
  componentId: string;
}

export function GenericPage(props: GenericPageProps) {
  const { componentId } = props;
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

  return <>{component}</>;
}
