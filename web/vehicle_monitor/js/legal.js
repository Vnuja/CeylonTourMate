import { elements } from "./ui.js";

const LEGAL_CONTENT = {
    tos: {
        title: "Terms of Service",
        content: `
            <h3>1. Introduction</h3>
            <p>Welcome to CeylonTourMate Vehicle Monitor. By using our application, you agree to these terms. Please read them carefully.</p>
            
            <h3>2. Use of Service</h3>
            <p>You must follow any policies made available to you within the Service. Do not misuse our Services. For example, do not interfere with our Services or try to access them using a method other than the interface and the instructions that we provide.</p>
            
            <h3>3. Privacy Protection</h3>
            <p>Our privacy policies explain how we treat your personal data and protect your privacy when you use our Services. By using our Services, you agree that CeylonTourMate can use such data in accordance with our privacy policies.</p>
            
            <h3>4. Your Content in our Services</h3>
            <p>Some of our Services allow you to upload, submit, store, send or receive content. You retain ownership of any intellectual property rights that you hold in that content. In short, what belongs to you stays yours.</p>
            
            <h3>5. Modifying and Terminating our Services</h3>
            <p>We are constantly changing and improving our Services. We may add or remove functionalities or features, and we may suspend or stop a Service altogether.</p>
        `
    },
    privacy: {
        title: "Privacy Policy",
        content: `
            <h3>1. Data Collection</h3>
            <p>We collect information to provide better services to all our users. We collect information in the following ways:</p>
            <ul>
                <li>Information you give us (e.g., your Google account details).</li>
                <li>Information we get from your use of our services (e.g., vehicle location, diagnostics).</li>
            </ul>
            
            <h3>2. How we use information</h3>
            <p>We use the information we collect from all of our services to provide, maintain, protect and improve them, to develop new ones, and to protect CeylonTourMate and our users.</p>
            
            <h3>3. Transparency and Choice</h3>
            <p>People have different privacy concerns. Our goal is to be clear about what information we collect, so that you can make meaningful choices about how it is used.</p>
            
            <h3>4. Information Security</h3>
            <p>We work hard to protect CeylonTourMate and our users from unauthorized access to or unauthorized alteration, disclosure or destruction of information we hold.</p>
        `
    }
};

export const initLegal = () => {
    const showModal = (type) => {
        const data = LEGAL_CONTENT[type];
        if (!data) return;

        elements.modalTitle.textContent = data.title;
        elements.modalContent.innerHTML = data.content;
        elements.legalModal.classList.add('active');
        
        // Prevent body scroll
        document.body.style.overflow = 'hidden';
    };

    const hideModal = () => {
        elements.legalModal.classList.remove('active');
        document.body.style.overflow = '';
    };

    // Event Listeners for all TOS links
    document.querySelectorAll('.tos-link').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            showModal('tos');
        });
    });

    // Event Listeners for all Privacy links
    document.querySelectorAll('.privacy-link').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            showModal('privacy');
        });
    });

    // Legacy support for ID-based links if any
    elements.tosLink?.addEventListener('click', (e) => {
        e.preventDefault();
        showModal('tos');
    });

    elements.privacyLink?.addEventListener('click', (e) => {
        e.preventDefault();
        showModal('privacy');
    });

    elements.closeModalBtn?.addEventListener('click', hideModal);
    elements.modalOkBtn?.addEventListener('click', hideModal);

    // Close on click outside
    elements.legalModal?.addEventListener('click', (e) => {
        if (e.target === elements.legalModal) {
            hideModal();
        }
    });

    // Close on Escape key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && elements.legalModal.classList.contains('active')) {
            hideModal();
        }
    });
};
