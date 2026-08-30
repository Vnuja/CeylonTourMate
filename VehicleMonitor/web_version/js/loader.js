/**
 * Utility to load HTML components into a container
 */
export const loadComponent = async (url, containerId) => {
    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`Failed to load ${url}`);
        const html = await response.text();
        const container = document.getElementById(containerId);
        if (!container) throw new Error(`Container not found: ${containerId}`);
        container.insertAdjacentHTML('beforeend', html);
        return true;
    } catch (error) {
        console.error("Component loading error:", error);
        return false;
    }
};
