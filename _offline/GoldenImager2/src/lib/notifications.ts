import { writable } from 'svelte/store';

export type NotificationType = 'info' | 'success' | 'warning' | 'error';

export interface Notification {
  id: string;
  type: NotificationType;
  message: string;
  timeout?: number;
}

const notifications = writable<Notification[]>([]);

export const notificationStore = {
  subscribe: notifications.subscribe,
  add: (message: string, type: NotificationType = 'info', timeout = 5000) => {
    const id = Math.random().toString(36).substring(2, 9);
    notifications.update(n => [...n, { id, type, message, timeout }]);
    
    if (timeout > 0) {
      setTimeout(() => {
        notificationStore.remove(id);
      }, timeout);
    }
    return id;
  },
  remove: (id: string) => {
    notifications.update(n => n.filter(item => item.id !== id));
  }
};
