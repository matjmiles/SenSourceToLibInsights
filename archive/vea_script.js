let modalRef;
let overlayRef;

function openModal() {
  modalRef.className = 'visible';
  overlayRef.className = 'visible';
}

function closeModal() {
  modalRef.className = 'hidden';
  overlayRef.className = 'hidden';
}


$(function() {
  modalRef = document.getElementById('modal');
  overlayRef = document.getElementById('overlay');

  const ui = SwaggerUIBundle({
    url: `${window.location.origin}/api-docs/api-docs-v1.2.0.json`,
    dom_id: '#swagger-ui',
    layout: 'BaseLayout',
    presets: [
      SwaggerUIBundle.presets.apis,
    ]
  });
})
