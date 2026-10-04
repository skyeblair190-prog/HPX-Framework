const app = document.getElementById('app')

window.addEventListener('message', ({ data }) => {
  if (!data || typeof data !== 'object') return

  if (data.action === 'render') {
    app.innerHTML = data.html || ''
  }

  if (data.action === 'clear') {
    app.replaceChildren()
  }
})
