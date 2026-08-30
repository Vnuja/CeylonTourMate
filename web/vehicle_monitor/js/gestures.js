export const initGestures = (onBackAction) => {
    let touchStartX = 0;
    let touchStartY = 0;
    let isGestureActive = false;
    let gestureType = null; // 'left' or 'right'
    const GESTURE_THRESHOLD = 80;
    const EDGE_THRESHOLD = 25;

    const gestureLeft = document.getElementById('gesture-left');
    const gestureRight = document.getElementById('gesture-right');

    const cancelGesture = () => {
        isGestureActive = false;
        gestureType = null;
        gestureLeft.classList.remove('active');
        gestureRight.classList.remove('active');
    };

    window.addEventListener('touchstart', (e) => {
        const touch = e.touches[0];
        touchStartX = touch.clientX;
        touchStartY = touch.clientY;
        
        if (touchStartX <= EDGE_THRESHOLD) {
            gestureType = 'left';
            isGestureActive = true;
        } else if (touchStartX >= window.innerWidth - EDGE_THRESHOLD) {
            gestureType = 'right';
            isGestureActive = true;
        }
    }, { passive: true });

    window.addEventListener('touchmove', (e) => {
        if (!isGestureActive) return;
        
        const touch = e.touches[0];
        const deltaX = Math.abs(touch.clientX - touchStartX);
        const deltaY = Math.abs(touch.clientY - touchStartY);
        
        if (deltaY > deltaX) {
            cancelGesture();
            return;
        }

        if (gestureType === 'left') {
            gestureLeft.classList.add('active');
        } else if (gestureType === 'right') {
            gestureRight.classList.add('active');
        }
    }, { passive: true });

    window.addEventListener('touchend', (e) => {
        if (!isGestureActive) return;
        
        const touch = e.changedTouches[0];
        const deltaX = Math.abs(touch.clientX - touchStartX);
        
        if (deltaX >= GESTURE_THRESHOLD) {
            onBackAction();
        }
        
        cancelGesture();
    });
};
