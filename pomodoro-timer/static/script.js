// adorable ECE Characters
const COLLECTIBLES = [
    { id: 'resistor', name: 'Resistor Rex', desc: 'First Friend', svg: `<svg viewBox="0 0 80 50" width="60"><rect x="5" y="20" width="70" height="10" rx="3" fill="#d4a574"/><circle cx="60" cy="25" r="5" fill="#2c3e50"/><circle cx="64" cy="25" r="2" fill="#fff"/></svg>` },
    { id: 'led', name: 'LED Lucy', desc: 'Shines Bright', svg: `<svg viewBox="0 0 80 70" width="60"><ellipse cx="40" cy="28" rx="15" ry="20" fill="#f1c40f"/><circle cx="35" cy="20" r="3" fill="#2c3e50"/><circle cx="45" cy="20" r="3" fill="#2c3e50"/></svg>` }
];

let state = {
    username: '',
    sessions: 0,
    pauses: 0,
    badges: 0
};

// Login Logic
document.getElementById('login-btn').addEventListener('click', () => {
    const user = document.getElementById('username-field').value;
    if(user) {
        state.username = user;
        document.getElementById('login-screen').classList.add('hidden');
        document.getElementById('dashboard').classList.remove('hidden');
        document.getElementById('username-display').innerText = `@${user}`;
        render();
    }
});

// Calculate Score
function getFocusScore() {
    if (state.sessions === 0) return 0;
    let score = 100 - (state.pauses * 10);
    return Math.max(score, 0);
}

// Update the Screen
function render() {
    document.getElementById('focus-score').innerText = getFocusScore();
    document.getElementById('total-sessions').innerText = state.sessions;
    
    const shelf = document.getElementById('trophy-shelf');
    shelf.innerHTML = '';
    
    const grid = document.createElement('div');
    grid.className = 'grid grid-cols-2 md:grid-cols-5 gap-6';
    
    COLLECTIBLES.forEach((item, index) => {
        const isUnlocked = state.sessions >= (index + 1) * 1; 
        const card = document.createElement('div');
        card.className = `badge-card p-4 rounded-2xl text-center ${isUnlocked ? 'bg-white shadow-md' : 'badge-locked opacity-50 bg-gray-200'}`;
        card.innerHTML = `
            <div class="mb-2 flex justify-center">${item.svg}</div>
            <div class="font-bold text-orange-800">${isUnlocked ? item.name : '???'}</div>
            <div class="text-xs text-orange-600">${isUnlocked ? item.desc : 'Finish 7 sessions'}</div>
        `;
        grid.appendChild(card);
    });
    shelf.appendChild(grid);
    lucide.createIcons();
}

// Demo session logging
document.getElementById('log-session-btn').addEventListener('click', () => {
    state.sessions++;
    state.pauses += parseInt(document.getElementById('pause-count').value || 0);
    render();
});