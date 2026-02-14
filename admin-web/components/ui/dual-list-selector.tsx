'use client'

import { useState } from 'react'
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
} from '@dnd-kit/core'
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'

interface Item {
  id: string
  title: string
  description?: string
}

interface DualListSelectorProps {
  availableItems: Item[]
  selectedItems: Item[]
  onSelectedChange: (items: Item[]) => void
  searchPlaceholder?: string
  leftLabel?: string
  rightLabel?: string
  disabled?: boolean
}

function SortableItem({
  item,
  onRemove,
  disabled,
}: {
  item: Item
  onRemove?: () => void
  disabled?: boolean
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: item.id })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  }

  return (
    <div
      ref={setNodeRef}
      style={style}
      className="group flex items-center gap-2 rounded-lg border border-gray-200 bg-white p-3 hover:border-gray-300"
    >
      {/* Drag Handle */}
      {!disabled && (
        <button
          type="button"
          className="cursor-grab text-gray-400 hover:text-gray-600 active:cursor-grabbing"
          {...attributes}
          {...listeners}
        >
          <svg
            className="h-5 w-5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 6h16M4 12h16M4 18h16"
            />
          </svg>
        </button>
      )}

      {/* Item Content */}
      <div className="flex-1">
        <p className="font-medium text-gray-900">{item.title}</p>
        {item.description && (
          <p className="text-sm text-gray-500">{item.description}</p>
        )}
      </div>

      {/* Remove Button */}
      {onRemove && !disabled && (
        <button
          type="button"
          onClick={onRemove}
          className="text-gray-400 opacity-0 hover:text-red-600 group-hover:opacity-100"
        >
          <svg
            className="h-5 w-5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      )}
    </div>
  )
}

export function DualListSelector({
  availableItems,
  selectedItems,
  onSelectedChange,
  searchPlaceholder = 'Search items...',
  leftLabel = 'Available',
  rightLabel = 'Selected',
  disabled = false,
}: DualListSelectorProps) {
  const [searchQuery, setSearchQuery] = useState('')

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  )

  // Filter available items (exclude already selected)
  const filteredAvailable = availableItems
    .filter((item) => !selectedItems.find((s) => s.id === item.id))
    .filter((item) =>
      item.title.toLowerCase().includes(searchQuery.toLowerCase())
    )

  const handleAddItem = (item: Item) => {
    if (!disabled) {
      onSelectedChange([...selectedItems, item])
    }
  }

  const handleRemoveItem = (itemId: string) => {
    if (!disabled) {
      onSelectedChange(selectedItems.filter((item) => item.id !== itemId))
    }
  }

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event

    if (over && active.id !== over.id) {
      const oldIndex = selectedItems.findIndex((item) => item.id === active.id)
      const newIndex = selectedItems.findIndex((item) => item.id === over.id)

      onSelectedChange(arrayMove(selectedItems, oldIndex, newIndex))
    }
  }

  return (
    <div className="grid gap-4 md:grid-cols-2">
      {/* Available Items (Left Panel) */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-medium text-gray-700">
            {leftLabel} ({filteredAvailable.length})
          </h3>
        </div>

        {/* Search */}
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder={searchPlaceholder}
          disabled={disabled}
          className="w-full rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50"
        />

        {/* Available Items List */}
        <div className="max-h-96 space-y-2 overflow-y-auto rounded-lg border border-gray-200 bg-gray-50 p-3">
          {filteredAvailable.length === 0 ? (
            <p className="py-8 text-center text-sm text-gray-500">
              {searchQuery ? 'No items found' : 'All items selected'}
            </p>
          ) : (
            filteredAvailable.map((item) => (
              <button
                key={item.id}
                type="button"
                onClick={() => handleAddItem(item)}
                disabled={disabled}
                className="w-full rounded-lg border border-gray-200 bg-white p-3 text-left hover:border-primary hover:bg-primary-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <p className="font-medium text-gray-900">{item.title}</p>
                {item.description && (
                  <p className="text-sm text-gray-500">{item.description}</p>
                )}
              </button>
            ))
          )}
        </div>
      </div>

      {/* Selected Items (Right Panel) */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-medium text-gray-700">
            {rightLabel} ({selectedItems.length})
          </h3>
          <span className="text-xs text-gray-500">
            {!disabled && 'Drag to reorder'}
          </span>
        </div>

        {/* Selected Items List with Drag & Drop */}
        <div className="max-h-96 space-y-2 overflow-y-auto rounded-lg border border-gray-200 bg-gray-50 p-3">
          {selectedItems.length === 0 ? (
            <p className="py-8 text-center text-sm text-gray-500">
              No items selected
            </p>
          ) : (
            <DndContext
              sensors={sensors}
              collisionDetection={closestCenter}
              onDragEnd={handleDragEnd}
            >
              <SortableContext
                items={selectedItems.map((item) => item.id)}
                strategy={verticalListSortingStrategy}
              >
                <div className="space-y-2">
                  {selectedItems.map((item, index) => (
                    <div key={item.id} className="flex items-center gap-2">
                      {/* Position Number */}
                      <span className="flex h-6 w-6 items-center justify-center rounded-full bg-primary-100 text-xs font-medium text-primary-800">
                        {index + 1}
                      </span>

                      {/* Sortable Item */}
                      <div className="flex-1">
                        <SortableItem
                          item={item}
                          onRemove={() => handleRemoveItem(item.id)}
                          disabled={disabled}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </SortableContext>
            </DndContext>
          )}
        </div>
      </div>
    </div>
  )
}
