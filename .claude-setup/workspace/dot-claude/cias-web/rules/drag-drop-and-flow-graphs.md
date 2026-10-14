# Drag & Drop and Flow Graphs

## Drag & Drop Libraries

The project uses **three** drag-and-drop libraries for different use cases:

| Library | Version | Use Case |
|---|---|---|
| `react-beautiful-dnd` | 13.1.0 | List reordering (questions, answers, sessions) |
| `@dnd-kit/core` + `@dnd-kit/sortable` | 5.0.3 / 10.0.0 | Newer sortable interactions |
| `react-sortable-tree` | 2.8.0 | Tree/hierarchy sorting |
| `react-draggable` | 4.4.6 | Free-form draggable elements |

### react-beautiful-dnd (primary)

Used for most list reordering in the app:

```tsx
import { DragDropContext, Droppable, Draggable } from 'react-beautiful-dnd';

<DragDropContext onDragEnd={handleDragEnd}>
  <Droppable droppableId="questions-list">
    {(provided) => (
      <div ref={provided.innerRef} {...provided.droppableProps}>
        {items.map((item, index) => (
          <Draggable key={item.id} draggableId={item.id} index={index}>
            {(provided, snapshot) => (
              <div
                ref={provided.innerRef}
                {...provided.draggableProps}
                {...provided.dragHandleProps}
              >
                {item.content}
              </div>
            )}
          </Draggable>
        ))}
        {provided.placeholder}
      </div>
    )}
  </Droppable>
</DragDropContext>
```

**Custom wrapper**: `app/components/DragAndDrop/`

### @dnd-kit (newer patterns)

Used in newer components where more fine-grained control is needed. Provides better TypeScript support and accessibility.

### react-sortable-tree

Used for hierarchical/tree structures that need drag-and-drop reordering with parent-child relationships.

---

## React Flow — Session Branching Diagrams

### Overview

`react-flow-renderer` (v9.7.4) powers the **session map** — a visual flowchart showing how sessions branch based on formulas and conditions.

**Components**: `app/components/ReactFlowGraph/`

### Custom edge routing

The project implements custom **path-finding edges** instead of React Flow's default straight/bezier edges:

```typescript
// PathFindingEdge — uses Dagre + Pathfinding algorithms
import dagre from 'dagre';
import PF from 'pathfinding';
```

This allows edges to route around nodes instead of overlapping them.

### Layout algorithm

Uses **Dagre** (`dagre@0.8.5`) for automatic graph layout:

```typescript
import dagre from 'dagre';

const dagreGraph = new dagre.graphlib.Graph();
dagreGraph.setDefaultEdgeLabel(() => ({}));
dagreGraph.setGraph({ rankdir: 'TB' }); // top-to-bottom layout
```

### Key utilities

| Utility | Location | Purpose |
|---|---|---|
| `SvgPathBuilder` | `app/utils/svg/SvgPathBuilder.ts` | Builds SVG path strings for custom edges |
| `SvgPathHelper` | `app/utils/svg/SvgPathHelper.ts` | Helper functions for SVG path calculations |
| Math utilities | `app/utils/mathUtils/` | Geometric calculations for node positioning |

### Graph features

- **Zoom to fit**: Auto-centers and scales the graph to show all nodes
- **Node dimension tracking**: Dynamically measures node sizes for layout
- **Transform calculations**: Custom viewport transforms for centering and scrolling
- **Interactive**: Nodes are clickable, navigating to session/question editors

---

## Key Rules

- **Match the existing DnD library** — use `react-beautiful-dnd` for list reordering unless the surrounding code uses `@dnd-kit`
- **Never mix DnD libraries** in the same component — each has its own context provider and they conflict
- **React Flow edges use custom pathfinding** — don't replace with default edges; the routing around nodes is intentional
- **Dagre handles layout** — don't manually position nodes; let the layout algorithm compute positions
