document.addEventListener('DOMContentLoaded', () => {
    // Check network health on page load
    checkNetworkHealth();

    // Load certificates by default
    loadCertificates();

    // Set up navigation
    document.getElementById('nav-certificates').addEventListener('click', function (e) {
        e.preventDefault();
        document.getElementById('certificates-section').style.display = 'block';
        document.getElementById('network-section').style.display = 'none';
        document.getElementById('nav-certificates').classList.add('active');
        document.getElementById('nav-network').classList.remove('active');
    });

    document.getElementById('nav-network').addEventListener('click', function (e) {
        e.preventDefault();
        document.getElementById('certificates-section').style.display = 'none';
        document.getElementById('network-section').style.display = 'block';
        document.getElementById('nav-certificates').classList.remove('active');
        document.getElementById('nav-network').classList.add('active');
        loadNetworkInfo();
    });

    // Setup modal handlers
    document.getElementById('submit-certificate').addEventListener('click', issueCertificate);
    document.getElementById('verify-certificate').addEventListener('click', verifyCertificate);
});

// Network Health Check
async function checkNetworkHealth() {
    try {
        const response = await fetch('/api/network/health');
        const data = await response.json();

        const indicator = document.getElementById('network-indicator');
        const statusText = document.getElementById('status-text');

        if (response.ok && data.status === 'ok') {
            indicator.classList.add('online');
            statusText.textContent = 'Connected';
        } else {
            indicator.classList.add('offline');
            statusText.textContent = 'Disconnected';
        }
    } catch (error) {
        console.error('Error checking network health:', error);
        const indicator = document.getElementById('network-indicator');
        const statusText = document.getElementById('status-text');

        indicator.classList.add('offline');
        statusText.textContent = 'Disconnected';
    }
}

// Load Certificates
async function loadCertificates() {
    try {
        const response = await fetch('/api/assets');

        if (!response.ok) {
            throw new Error('Failed to fetch certificates');
        }

        const certificates = await response.json();
        const tableBody = document.getElementById('certificates-table-body');

        if (certificates.length === 0) {
            tableBody.innerHTML = '<tr><td colspan="6" class="text-center">No certificates found</td></tr>';
            return;
        }

        tableBody.innerHTML = '';

        certificates.forEach(cert => {
            const row = document.createElement('tr');

            // Extract the correct certificate ID based on the structure
            const certID = cert.certID || cert.CertID || cert.id || cert.ID;

            // Certificate ID column
            const idCell = document.createElement('td');
            idCell.textContent = certID;
            row.appendChild(idCell);

            // Recipient column
            const recipientCell = document.createElement('td');
            recipientCell.textContent = cert.studentID || cert.StudentID || cert.recipient || cert.Recipient || 'N/A';
            row.appendChild(recipientCell);

            // Issuer column
            const issuerCell = document.createElement('td');
            issuerCell.textContent = cert.issuer || cert.Issuer || 'N/A';
            row.appendChild(issuerCell);

            // Issue Date column
            const dateCell = document.createElement('td');
            dateCell.textContent = cert.IssueDate || cert.issueDate || 'N/A';
            row.appendChild(dateCell);

            // Status column
            const statusCell = document.createElement('td');
            const status = cert.Status || cert.status || 'Active';
            const statusBadge = document.createElement('span');
            statusBadge.className = `badge ${status.toLowerCase() === 'revoked' ? 'bg-danger' : 'bg-success'}`;
            statusBadge.textContent = status;
            statusCell.appendChild(statusBadge);
            row.appendChild(statusCell);

            // Actions column
            const actionsCell = document.createElement('td');
            const actionsDiv = document.createElement('div');
            actionsDiv.className = 'btn-group-sm';

            // View button
            const viewBtn = document.createElement('button');
            viewBtn.className = 'btn btn-outline-primary btn-action me-1';
            viewBtn.textContent = 'View';
            viewBtn.addEventListener('click', () => viewCertificate(certID));

            // Revoke button
            const revokeBtn = document.createElement('button');
            revokeBtn.className = 'btn btn-outline-danger btn-action';
            revokeBtn.textContent = 'Revoke';
            revokeBtn.addEventListener('click', () => revokeCertificate(certID));

            if (status.toLowerCase() === 'revoked') {
                revokeBtn.disabled = true;
            }

            actionsDiv.appendChild(viewBtn);
            actionsDiv.appendChild(revokeBtn);
            actionsCell.appendChild(actionsDiv);
            row.appendChild(actionsCell);

            tableBody.appendChild(row);
        });
    } catch (error) {
        console.error('Error loading certificates:', error);
        showNotification('Error loading certificates: ' + error.message, 'danger');

        const tableBody = document.getElementById('certificates-table-body');
        tableBody.innerHTML = '<tr><td colspan="6" class="text-center text-danger">Error loading certificates</td></tr>';
    }
}

// Load Network Info
async function loadNetworkInfo() {
    try {
        // Get network info
        const infoResponse = await fetch('/api/network/info');

        if (!infoResponse.ok) {
            throw new Error('Failed to fetch network info');
        }

        const networkInfo = await infoResponse.json();

        // Update channel info
        document.getElementById('channel-name').textContent = networkInfo.channelName || 'mychannel';
        document.getElementById('block-height').textContent = networkInfo.channelInfo?.height || 'Information unavailable';

        // Get chaincodes
        const chaincodesResponse = await fetch('/api/network/chaincodes');

        if (!chaincodesResponse.ok) {
            throw new Error('Failed to fetch chaincodes');
        }

        const chaincodes = await chaincodesResponse.json();
        const chaincodesList = document.getElementById('chaincodes-list');

        if (chaincodes.length === 0) {
            chaincodesList.innerHTML = '<li class="list-group-item">No chaincodes installed</li>';
            return;
        }

        chaincodesList.innerHTML = '';

        chaincodes.forEach(chaincode => {
            const item = document.createElement('li');
            item.className = 'list-group-item';
            item.innerHTML = `<strong>${chaincode.name}</strong> (v${chaincode.version})`;
            chaincodesList.appendChild(item);
        });
    } catch (error) {
        console.error('Error loading network info:', error);
        showNotification('Error loading network information: ' + error.message, 'danger');
    }
}

// Issue Certificate
async function issueCertificate() {
    // Trim input values to prevent whitespace issues
    const id = document.getElementById('certificate-id').value.trim();
    const recipient = document.getElementById('certificate-recipient').value.trim();
    const issuer = document.getElementById('certificate-issuer').value.trim();
    let data = null;

    // Try to parse the additional data if provided
    const dataText = document.getElementById('certificate-data').value;
    if (dataText) {
        try {
            data = JSON.parse(dataText);
        } catch (e) {
            showNotification('Invalid JSON in Additional Data field', 'warning');
            return;
        }
    }

    // Validate form
    if (!id || !recipient || !issuer) {
        showNotification('Please fill in required fields: ID, Recipient, and Issuer', 'warning');
        return;
    }

    try {
        const response = await fetch('/api/assets', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                id: id,
                recipient: recipient,
                issuer: issuer,
                data: data
            })
        });

        const result = await response.json();

        if (!response.ok) {
            throw new Error(result.error || 'Failed to issue certificate');
        }

        // Reset form and close modal
        document.getElementById('certificate-form').reset();
        const modal = bootstrap.Modal.getInstance(document.getElementById('certificateModal'));
        modal.hide();

        // Show success message and reload certificates
        showNotification('Certificate issued successfully', 'success');
        loadCertificates();
    } catch (error) {
        console.error('Error issuing certificate:', error);
        showNotification('Error issuing certificate: ' + error.message, 'danger');
    }
}

// View Certificate Details
async function viewCertificate(certificateId) {
    try {
        // Validate certificateId
        if (!certificateId || certificateId === 'undefined') {
            showNotification('Invalid certificate ID', 'danger');
            return;
        }

        // Show the modal first with loading state
        const detailsModal = new bootstrap.Modal(document.getElementById('certificateDetailsModal'));
        detailsModal.show();

        const detailsBody = document.getElementById('certificate-details-body');
        detailsBody.innerHTML = `
            <div class="d-flex justify-content-center">
                <div class="spinner-border text-primary" role="status">
                    <span class="visually-hidden">Loading...</span>
                </div>
            </div>
        `;

        // Set the certificate ID on the verify button for later use
        document.getElementById('verify-certificate').setAttribute('data-certificate-id', certificateId);

        // Fetch the certificate details
        const response = await fetch(`/api/assets/${certificateId}`);

        if (!response.ok) {
            throw new Error(`Failed to fetch certificate: ${response.statusText}`);
        }

        const certificate = await response.json();

        // Format the certificate details for display
        let detailsHTML = `
            <div class="certificate-details">
                <div class="row mb-3">
                    <div class="col-md-4"><strong>Certificate ID:</strong></div>
                    <div class="col-md-8">${certificate.certID || certificate.CertID || certificate.id || certificate.ID || certificateId}</div>
                </div>
                <div class="row mb-3">
                    <div class="col-md-4"><strong>Recipient:</strong></div>
                    <div class="col-md-8">${certificate.studentID || certificate.StudentID || certificate.recipient || certificate.Recipient || 'N/A'}</div>
                </div>
                <div class="row mb-3">
                    <div class="col-md-4"><strong>Issuer:</strong></div>
                    <div class="col-md-8">${certificate.issuer || certificate.Issuer || 'N/A'}</div>
                </div>
                <div class="row mb-3">
                    <div class="col-md-4"><strong>Issue Date:</strong></div>
                    <div class="col-md-8">${certificate.IssueDate || certificate.issueDate || 'N/A'}</div>
                </div>
                <div class="row mb-3">
                    <div class="col-md-4"><strong>Status:</strong></div>
                    <div class="col-md-8">
                        <span class="badge ${(certificate.Status || certificate.status || 'Active').toLowerCase() === 'revoked' ? 'bg-danger' : 'bg-success'}">
                            ${certificate.Status || certificate.status || 'Active'}
                        </span>
                    </div>
                </div>
        `;

        // Add additional data if available
        if (certificate.Data || certificate.data) {
            const additionalData = certificate.Data || certificate.data;
            detailsHTML += `
                <div class="row">
                    <div class="col-md-4"><strong>Additional Data:</strong></div>
                    <div class="col-md-8">
                        <pre class="certificate-data">${JSON.stringify(additionalData, null, 2)}</pre>
                    </div>
                </div>
            `;
        }

        detailsHTML += `</div>`;

        // Update the modal body with the certificate details
        detailsBody.innerHTML = detailsHTML;

    } catch (error) {
        console.error('Error viewing certificate:', error);
        document.getElementById('certificate-details-body').innerHTML = `
            <div class="alert alert-danger">
                Error loading certificate details: ${error.message}
            </div>
        `;
    }
}

// Verify Certificate
async function verifyCertificate() {
    try {
        const certificateId = document.getElementById('verify-certificate').getAttribute('data-certificate-id');

        // Validate certificate ID
        if (!certificateId || certificateId === 'undefined') {
            showNotification('Invalid certificate ID', 'danger');
            return;
        }

        const verifyButton = document.getElementById('verify-certificate');
        const originalText = verifyButton.textContent;
        verifyButton.disabled = true;
        verifyButton.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Verifying...';

        // Call the verify endpoint
        const response = await fetch(`/api/assets/${certificateId}/verify`);

        if (!response.ok) {
            throw new Error(`Failed to verify certificate: ${response.statusText}`);
        }

        const result = await response.json();
        const isValid = result.valid === true || (typeof result.valid === 'string' && result.valid.toLowerCase() === 'true');

        // Show verification result
        const detailsBody = document.getElementById('certificate-details-body');
        const verificationDiv = document.createElement('div');
        verificationDiv.className = `alert ${isValid ? 'alert-success' : 'alert-danger'} mt-3`;
        verificationDiv.innerHTML = `
            <strong>${isValid ? 'Certificate is valid!' : 'Certificate verification failed!'}</strong><br>
            The blockchain confirms this certificate ${isValid ? 'is authentic' : 'has issues'}.
        `;

        // Append to the end of the details body
        detailsBody.appendChild(verificationDiv);

        // Reset button
        verifyButton.textContent = originalText;
        verifyButton.disabled = false;

    } catch (error) {
        console.error('Error verifying certificate:', error);
        showNotification('Error verifying certificate: ' + error.message, 'danger');

        // Reset button
        const verifyButton = document.getElementById('verify-certificate');
        verifyButton.textContent = 'Verify Certificate';
        verifyButton.disabled = false;
    }
}

// Revoke Certificate
async function revokeCertificate(certificateId) {
    if (!confirm(`Are you sure you want to revoke certificate ${certificateId}?`)) {
        return;
    }

    try {
        const response = await fetch(`/api/assets/${certificateId}`, {
            method: 'DELETE'
        });

        const result = await response.json();

        if (!response.ok) {
            throw new Error(result.error || 'Failed to revoke certificate');
        }

        // Show success message and reload certificates
        showNotification(`Certificate ${certificateId} has been revoked`, 'success');
        loadCertificates();
    } catch (error) {
        console.error('Error revoking certificate:', error);
        showNotification('Error revoking certificate: ' + error.message, 'danger');
    }
}

// Show Notification
function showNotification(message, type) {
    // Check if toast container exists, if not create it
    let toastContainer = document.querySelector('.toast-container');

    if (!toastContainer) {
        toastContainer = document.createElement('div');
        toastContainer.className = 'toast-container';
        document.body.appendChild(toastContainer);
    }

    // Create toast element
    const toastEl = document.createElement('div');
    toastEl.className = `toast align-items-center text-white bg-${type} border-0`;
    toastEl.setAttribute('role', 'alert');
    toastEl.setAttribute('aria-live', 'assertive');
    toastEl.setAttribute('aria-atomic', 'true');

    // Create toast body
    const toastBody = document.createElement('div');
    toastBody.className = 'd-flex';

    const messageDiv = document.createElement('div');
    messageDiv.className = 'toast-body';
    messageDiv.textContent = message;

    const closeButton = document.createElement('button');
    closeButton.type = 'button';
    closeButton.className = 'btn-close btn-close-white me-2 m-auto';
    closeButton.setAttribute('data-bs-dismiss', 'toast');
    closeButton.setAttribute('aria-label', 'Close');

    toastBody.appendChild(messageDiv);
    toastBody.appendChild(closeButton);
    toastEl.appendChild(toastBody);

    // Add to container
    toastContainer.appendChild(toastEl);

    // Initialize and show the toast
    const toast = new bootstrap.Toast(toastEl, {
        autohide: true,
        delay: 5000
    });
    toast.show();

    // Remove the toast after it's hidden
    toastEl.addEventListener('hidden.bs.toast', () => {
        toastEl.remove();
    });
}
