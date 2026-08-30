// State for elements that might not be in the DOM immediately
export const elements = {
    screenContainer: document.getElementById('screen-container'),
    loader: document.getElementById('loader'),
    // These will be populated after load
    loginScreen: null,
    dashboardScreen: null,
    signinBtn: null,
    signoutBtn: null,
    userName: null,
    userAvatar: null,
    avatarInitial: null,
    displayNameText: null,
    displayEmailText: null,
    // Legal Modal Elements
    tosLink: null,
    privacyLink: null,
    legalModal: null,
    modalTitle: null,
    modalContent: null,
    closeModalBtn: null,
    modalOkBtn: null,
    // Notification UI
    notifBtn: null,
    notifBadge: null,
    notifPanel: null,
    closeNotifBtn: null,
    clearAllNotifBtn: null
};


/**
 * Initializes DOM references once components are loaded
 */
export const initElements = () => {
    elements.loginScreen = document.getElementById('login-screen');
    elements.dashboardScreen = document.getElementById('dashboard-screen');
    elements.signinBtn = document.getElementById('google-signin-btn');
    elements.signoutBtn = document.getElementById('signout-btn');
    elements.userName = document.getElementById('user-name');
    elements.userAvatar = document.getElementById('user-avatar');
    elements.avatarInitial = document.getElementById('avatar-initial');
    elements.displayNameText = document.getElementById('display-name-text');
    elements.displayEmailText = document.getElementById('display-email-text');
    
    // Legal Modal
    elements.tosLink = document.getElementById('tos-link');
    elements.privacyLink = document.getElementById('privacy-link');
    elements.legalModal = document.getElementById('legal-modal');
    elements.modalTitle = document.getElementById('modal-title');
    elements.modalContent = document.getElementById('modal-content');
    elements.closeModalBtn = document.getElementById('close-modal');
    elements.modalOkBtn = document.getElementById('modal-ok-btn');
    
    // Notification UI
    elements.notifBtn = document.getElementById('notif-btn');
    elements.notifBadge = document.getElementById('notif-badge');
    elements.notifPanel = document.getElementById('notif-panel');
    elements.closeNotifBtn = document.getElementById('close-notif');
    elements.clearAllNotifBtn = document.getElementById('clear-all-notif');
};


export const showLoader = (show) => {
    elements.loader.classList.toggle('active', show);
};

export const updateUI = (user) => {
    if (!elements.loginScreen) return; // Not initialized yet

    if (user) {
        elements.userName.textContent = user.displayName?.split(' ')[0] || 'Driver';
        elements.displayNameText.textContent = user.displayName || 'User';
        elements.displayEmailText.textContent = user.email || '';
        
        if (user.photoURL) {
            elements.userAvatar.style.backgroundImage = `url(${user.photoURL})`;
            elements.avatarInitial.textContent = '';
        } else {
            elements.userAvatar.style.backgroundImage = 'none';
            elements.avatarInitial.textContent = (user.displayName || 'U')[0].toUpperCase();
        }
        
        elements.loginScreen.classList.remove('active');
        elements.dashboardScreen.classList.add('active');
    } else {
        elements.loginScreen.classList.add('active');
        elements.dashboardScreen.classList.remove('active');
    }
    showLoader(false);
};
