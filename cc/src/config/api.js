import axios from 'axios';

const base = (process.env.REACT_APP_API_BASE_URL ?? 'http://localhost:5000').replace(/\/$/, '');

const apiClient = axios.create({
  baseURL: base,
});

export const apiBaseUrl = base;

export const resolveApiUrl = (path = '') => {
  if (!path) {
    return base;
  }
  const normalizedPath = path.startsWith('/') ? path.slice(1) : path;
  return `${base}/${normalizedPath}`;
};

export default apiClient;