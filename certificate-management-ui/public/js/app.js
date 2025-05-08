// Global state
const state = {
  apiKey: null,
  organization: null,
  currentCertificateId: null
};

// DOM Elements
const elements = {
  loginScreen: document.getElementById('login-screen'),
  appContainer: document.getElementById('app-container'),
  userInfo: document.getElementById('user-info'),
  userOrgBadge: document.getElementById('user-org-badge'),
  logoutBtn: document.getElementById('logout-btn'),
  tabs: {
    viewTab: document.getElementById('view-tab'),
    issueTab: document.getElementById('issue-tab'),
    verifyTab: document.getElementById('verify-tab'),
    issueTabContainer: document.getElementById('issue-tab-container')
  },
  sections: {
    // viewCertificates: document.getElementById('view-pane'),
    issueCertificate: document.getElementById('issue-pane'),
    verifyCertificate: document.getElementById('verify-pane')
  },
  forms: {
    loginForm: document.getElementById('login-form'),
    issueForm: document.getElementById('issue-form'),
    verifyForm: document.getElementById('verify-form')
  },
  containers: {
    certificatesContainer: document.getElementById('certificates-container'),
    certificatesLoading: document.getElementById('certificates-loading'),
    alertsContainer: document.getElementById('alerts-container')
  },
  errors: {
    loginError: document.getElementById('login-error'),
    issueError: document.getElementById('issue-error'),
    verifyError: document.getElementById('verify-error')
  },
  verificationResult: document.getElementById('verification-result'),
  modal: {
    certificateModal: new bootstrap.Modal(document.getElementById('certificate-modal')),
    modalBody: document.getElementById('certificate-modal-body'),
    revokeCertBtn: document.getElementById('revoke-cert-btn')
  }
};

// API Service with API key authentication
const api = {
  // Certificate endpoints
  getAllCertificates: async (org) => {
    try {
      const response = await fetch(`/api/${org}/certificates`, {
        headers: {
          'X-API-Key': state.apiKey
        }
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to fetch certificates');
      }

      return response.json();
    } catch (error) {
      console.error('Error fetching certificates:', error);
      throw error;
    }
  },

  getCertificate: async (org, certId) => {
    const response = await fetch(`/api/${org}/certificates/${certId}`, {
      headers: {
        'X-API-Key': state.apiKey
      }
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to fetch certificate');
    }

    return response.json();
  },

  verifyCertificate: async (org, certId) => {
    const response = await fetch(`/api/${org}/certificates/verify/${certId}`, {
      headers: {
        'X-API-Key': state.apiKey
      }
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to verify certificate');
    }

    return response.json();
  },

  issueCertificate: async (data) => {
    try {
      const response = await fetch(`/api/${state.organization}/certificates`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': state.apiKey
        },
        body: JSON.stringify(data)
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to issue certificate');
      }

      return response.json();
    } catch (error) {
      console.error('Error issuing certificate:', error);
      throw error;
    }
  },

  revokeCertificate: async (certId) => {
    const response = await fetch(`/api/university/certificates/${certId}`, {
      method: 'DELETE',
      headers: {
        'X-API-Key': state.apiKey
      }
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to revoke certificate');
    }

    return response.json();
  },

  // Get organization info
  getOrgInfo: async () => {
    const response = await fetch('/api/org-info');

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to fetch organization info');
    }

    return response.json();
  }
};

// UI Controller
const ui = {
  showError: (element, message) => {
    element.textContent = message;
    element.classList.remove('hidden');
  },

  hideError: (element) => {
    element.textContent = '';
    element.classList.add('hidden');
  },

  showAlert: (message, type = 'success') => {
    const alertId = `alert-${Date.now()}`;
    const alertHtml = `
      <div id="${alertId}" class="alert alert-${type} alert-dismissible fade show" role="alert">
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
      </div>
    `;

    elements.containers.alertsContainer.insertAdjacentHTML('afterbegin', alertHtml);

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      const alertElement = document.getElementById(alertId);
      if (alertElement) {
        const bsAlert = bootstrap.Alert.getOrCreateInstance(alertElement);
        bsAlert.close();
      }
    }, 5000);
  },

  showSection: (section) => {
    // Hide all sections
    Object.values(elements.sections).forEach(s => s.classList.add('hidden'));

    // Show the specified section
    section.classList.remove('hidden');
  },

  setActiveTab: (tab) => {
    // Remove active class from all tabs
    Object.values(elements.tabs).forEach(t => t.classList.remove('active'));

    // Add active class to the specified tab
    tab.classList.add('active');
  },

  displayUserInfo: () => {
    if (!state.user) return;

    elements.userInfo.textContent = `${state.user.username}`;

    let badgeClass = '';
    switch (state.user.org) {
      case 'org1':
        badgeClass = 'bg-success';
        break;
      case 'org2':
        badgeClass = 'bg-primary';
        break;
      case 'org3':
        badgeClass = 'bg-secondary';
        break;
      default:
        badgeClass = 'bg-dark';
    }

    elements.userOrgBadge.textContent = state.user.orgName;
    elements.userOrgBadge.className = `badge ${badgeClass}`;
  },

  updateUIBasedOnPermissions: () => {
    if (!state.permissions) return;

    // Show/hide issue certificate tab based on permissions
    if (!state.permissions.canIssue) {
      elements.tabs.issueTabContainer.classList.add('hidden');
    } else {
      elements.tabs.issueTabContainer.classList.remove('hidden');
    }

    // Show/hide revoke button in certificate detail modal
    if (!state.permissions.canRevoke) {
      elements.modal.revokeCertBtn.classList.add('hidden');
    } else {
      elements.modal.revokeCertBtn.classList.remove('hidden');
    }
  },

  displayCertificates: (certificates) => {
    elements.containers.certificatesLoading.classList.add('hidden');
    elements.containers.certificatesContainer.innerHTML = '';

    if (!certificates || certificates.length === 0) {
      elements.containers.certificatesContainer.innerHTML = `
        <div class="col-12">
          <div class="alert alert-info">No certificates found.</div>
        </div>
      `;
      return;
    }

    certificates.forEach(cert => {
      const certId = cert.certID || cert.CertID;
      const studentId = cert.studentID || cert.StudentID;
      const issuer = cert.issuer || cert.Issuer;

      const cardHtml = `
        <div class="col-md-6 col-lg-4">
          <div class="card certificate-card">
            <div class="card-header">
              <strong>Certificate ID:</strong> ${certId}
            </div>
            <div class="card-body">
              <p class="card-text"><strong>Student ID:</strong> ${studentId || 'N/A'}</p>
              <p class="card-text"><strong>Issuer:</strong> ${issuer || 'N/A'}</p>
              <button class="btn btn-sm btn-primary view-cert-btn" data-cert-id="${certId}">View Details</button>
            </div>
          </div>
        </div>
      `;

      elements.containers.certificatesContainer.insertAdjacentHTML('beforeend', cardHtml);
    });

    // Add event listeners to view buttons
    document.querySelectorAll('.view-cert-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const certId = btn.getAttribute('data-cert-id');
        await ui.showCertificateDetails(certId);
      });
    });
  },

  showCertificateDetails: async (certId) => {
    try {
      // Show modal with loading state
      elements.modal.modalBody.innerHTML = `
        <div class="text-center">
          <div class="spinner-border" role="status">
            <span class="visually-hidden">Loading...</span>
          </div>
        </div>
      `;

      elements.modal.certificateModal.show();
      state.currentCertificateId = certId;

      const certificate = await api.getCertificate(state.organization, certId);

      // Format certificate details
      const certId_display = certificate.certID || certificate.CertID || certId;
      const studentId_display = certificate.studentID || certificate.StudentID || 'N/A';
      const certHash_display = certificate.certHash || certificate.CertHash || 'N/A';
      const issuer_display = certificate.issuer || certificate.Issuer || 'N/A';

      const detailsHtml = `
        <div class="certificate-details">
          <div class="row mb-2">
            <div class="col-md-4"><strong>Certificate ID:</strong></div>
            <div class="col-md-8">${certId_display}</div>
          </div>
          <div class="row mb-2">
            <div class="col-md-4"><strong>Student ID:</strong></div>
            <div class="col-md-8">${studentId_display}</div>
          </div>
          <div class="row mb-2">
            <div class="col-md-4"><strong>Certificate Hash:</strong></div>
            <div class="col-md-8">${certHash_display}</div>
          </div>
          <div class="row mb-2">
            <div class="col-md-4"><strong>Issuer:</strong></div>
            <div class="col-md-8">${issuer_display}</div>
          </div>
        </div>
      `;

      elements.modal.modalBody.innerHTML = detailsHtml;

    } catch (error) {
      console.error('Error fetching certificate details:', error);
      elements.modal.modalBody.innerHTML = `
        <div class="alert alert-danger">
          Failed to load certificate details: ${error.message}
        </div>
      `;
    }
  }
};

// App Controller
const app = {
  init: async () => {
    app.bindEvents();
    await app.checkAuthentication();
  },

  bindEvents: () => {
    // Auth events
    elements.forms.loginForm.addEventListener('submit', app.handleLogin);
    elements.logoutBtn.addEventListener('click', app.handleLogout);

    // Tab navigation
    elements.tabs.viewTab.addEventListener('click', (e) => {
      e.preventDefault();
      ui.setActiveTab(elements.tabs.viewTab);
      ui.showSection(elements.sections.viewCertificates);
      app.loadCertificates();
    });

    elements.tabs.issueTab.addEventListener('click', (e) => {
      e.preventDefault();
      ui.setActiveTab(elements.tabs.issueTab);
      ui.showSection(elements.sections.issueCertificate);
    });

    elements.tabs.verifyTab.addEventListener('click', (e) => {
      e.preventDefault();
      ui.setActiveTab(elements.tabs.verifyTab);
      ui.showSection(elements.sections.verifyCertificate);
    });

    // Form submissions
    elements.forms.issueForm.addEventListener('submit', app.handleIssueCertificate);
    elements.forms.verifyForm.addEventListener('submit', app.handleVerifyCertificate);

    // Certificate actions
    elements.modal.revokeCertBtn.addEventListener('click', app.handleRevokeCertificate);

    console.log('Setting up issue form handler');
    elements.forms.issueForm.addEventListener('submit', function (e) {
      console.log('Form submitted!');
      e.preventDefault();
      app.handleIssueCertificate(e);
    });
  },

  checkAuthentication: async () => {
    try {
      const session = await api.getSession();

      if (session && session.user) {
        state.user = session.user;
        state.permissions = session.permissions;

        // Show app container, hide login screen
        elements.loginScreen.classList.add('hidden');
        elements.appContainer.classList.remove('hidden');

        // Update UI based on user and permissions
        ui.displayUserInfo();
        ui.updateUIBasedOnPermissions();

        // Load certificates
        app.loadCertificates();
      } else {
        // Show login screen, hide app container
        elements.loginScreen.classList.remove('hidden');
        elements.appContainer.classList.add('hidden');
      }
    } catch (error) {
      console.error('Error checking authentication:', error);
      // Show login screen on error
      elements.loginScreen.classList.remove('hidden');
      elements.appContainer.classList.add('hidden');
    }
  },

  handleLogin: async (e) => {
    e.preventDefault();

    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;

    try {
      ui.hideError(elements.errors.loginError);

      const userData = await api.login(username, password);
      state.user = {
        id: userData.id,
        username: userData.username,
        org: userData.org,
        orgName: userData.orgName,
        role: userData.role
      };
      state.permissions = userData.permissions;

      // Show app container, hide login screen
      elements.loginScreen.classList.add('hidden');
      elements.appContainer.classList.remove('hidden');

      // Update UI based on user and permissions
      ui.displayUserInfo();
      ui.updateUIBasedOnPermissions();

      // Load certificates
      app.loadCertificates();

    } catch (error) {
      console.error('Login error:', error);
      ui.showError(elements.errors.loginError, error.message);
    }
  },

  handleLogout: async () => {
    try {
      await api.logout();

      // Reset state
      state.user = null;
      state.permissions = null;

      // Show login screen, hide app container
      elements.loginScreen.classList.remove('hidden');
      elements.appContainer.classList.add('hidden');

    } catch (error) {
      console.error('Logout error:', error);
      ui.showAlert('Failed to logout: ' + error.message, 'danger');
    }
  },

  loadCertificates: async () => {
    try {
      elements.containers.certificatesLoading.classList.remove('hidden');
      elements.containers.certificatesContainer.innerHTML = '';

      const certificates = await api.getAllCertificates(state.organization);
      ui.displayCertificates(certificates);

    } catch (error) {
      console.error('Error loading certificates:', error);
      elements.containers.certificatesLoading.classList.add('hidden');
      ui.showAlert('Failed to load certificates: ' + error.message, 'danger');
    }
  },

  handleIssueCertificate: async (e) => {
    e.preventDefault();
    console.log('Issue certificate form submitted');

    // Get the issue error element
    const errorElement = document.getElementById('issue-error');
    if (errorElement) errorElement.classList.add('hidden');

    try {
      // Get form values
      const studentID = document.getElementById('student-id').value.trim();
      const certID = document.getElementById('cert-id').value.trim();
      const certHash = document.getElementById('cert-hash').value.trim();
      const issuer = document.getElementById('issuer').value.trim() || 'UniversityOrg'; // Default to UniversityOrg if empty

      console.log('Form values:', { studentID, certID, certHash, issuer });

      // Validate form inputs
      if (!studentID || !certID || !certHash) {
        if (errorElement) {
          errorElement.textContent = 'Please fill all required fields';
          errorElement.classList.remove('hidden');
        } else {
          alert('Please fill all required fields');
        }
        return;
      }

      // Show loading state
      const submitBtn = document.getElementById('issue-cert-btn');
      const originalText = submitBtn.textContent;
      submitBtn.disabled = true;
      submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Processing...';

      // Submit the certificate issuance request
      const response = await api.issueCertificate({
        studentID,
        certID,
        certHash,
        issuer
      });

      console.log('Certificate issued response:', response);

      // Clear form
      document.getElementById('issue-form').reset();

      // Show success message
      const alertsContainer = document.getElementById('alerts-container');
      if (alertsContainer) {
        const alertId = `alert-${Date.now()}`;
        alertsContainer.innerHTML = `
          <div id="${alertId}" class="alert alert-success alert-dismissible fade show" role="alert">
            Certificate issued successfully!
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
          </div>
        ` + alertsContainer.innerHTML;

        // Auto-dismiss after 5 seconds
        setTimeout(() => {
          const alertElement = document.getElementById(alertId);
          if (alertElement) {
            alertElement.remove();
          }
        }, 5000);
      } else {
        alert('Certificate issued successfully!');
      }

      // Reset button state
      submitBtn.disabled = false;
      submitBtn.textContent = originalText;

      // Load updated certificates
      await app.loadCertificates();

      // Switch to view certificates tab
      document.getElementById('view-tab').click();

    } catch (error) {
      console.error('Error issuing certificate:', error);

      // Handle error display
      if (errorElement) {
        errorElement.textContent = error.message || 'Failed to issue certificate';
        errorElement.classList.remove('hidden');
      } else {
        alert('Error: ' + (error.message || 'Failed to issue certificate'));
      }

      // Reset button state if necessary
      const submitBtn = document.getElementById('issue-cert-btn');
      if (submitBtn && submitBtn.disabled) {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Issue Certificate';
      }
    }
  },

  handleVerifyCertificate: async (e) => {
    e.preventDefault();

    const certId = document.getElementById('verify-cert-id').value;

    try {
      ui.hideError(elements.errors.verifyError);
      elements.verificationResult.classList.add('hidden');

      const result = await api.verifyCertificate(state.organization, certId);

      // Show verification result
      const isValid = result.valid === true || (typeof result.valid === 'string' && result.valid.toLowerCase() === 'true');

      elements.verificationResult.innerHTML = `
        <div class="alert ${isValid ? 'alert-success' : 'alert-danger'}">
          <strong>${isValid ? 'Certificate is valid!' : 'Certificate verification failed!'}</strong><br>
          The blockchain confirms this certificate ${isValid ? 'is authentic' : 'has issues'}.
        </div>
      `;

      elements.verificationResult.classList.remove('hidden');

    } catch (error) {
      console.error('Error verifying certificate:', error);
      ui.showError(elements.errors.verifyError, error.message);
    }
  },

  handleRevokeCertificate: async () => {
    if (!state.currentCertificateId) return;

    if (!confirm(`Are you sure you want to revoke certificate ${state.currentCertificateId}?`)) {
      return;
    }

    try {
      await api.revokeCertificate(state.currentCertificateId);

      // Hide modal
      elements.modal.certificateModal.hide();

      // Show success message
      ui.showAlert('Certificate revoked successfully');

      // Reload certificates
      app.loadCertificates();

    } catch (error) {
      console.error('Error revoking certificate:', error);
      ui.showAlert('Failed to revoke certificate: ' + error.message, 'danger');
    }
  }
};

// Function to handle organization selection and login
function selectOrg(organization) {
  const apiKeyElement = document.getElementById(`${organization}-api-key`);
  const apiKey = apiKeyElement.value.trim();

  if (!apiKey) {
    alert(`Please enter the API key for ${organization} organization`);
    return;
  }

  // Store API key and organization in state
  state.apiKey = apiKey;
  state.organization = organization;

  // Hide the organization selection screen
  document.getElementById('org-selection').classList.add('hidden');

  // Show the main application
  document.getElementById('main-app').classList.remove('hidden');

  // Set organization badge
  const orgBadge = document.getElementById('org-badge');
  orgBadge.textContent = organization.charAt(0).toUpperCase() + organization.slice(1);
  orgBadge.className = `badge org-badge ${organization}-badge`;

  // Configure UI based on organization type
  if (organization === 'university') {
    document.getElementById('issue-tab').parentElement.classList.remove('hidden');
  } else {
    document.getElementById('issue-tab').parentElement.classList.add('hidden');
  }

  // Load certificates
  app.loadCertificates();
}

// Function to handle logout
document.getElementById('logout-btn').addEventListener('click', function () {
  // Reset state
  state.apiKey = null;
  state.organization = null;

  // Show organization selection, hide main app
  document.getElementById('org-selection').classList.remove('hidden');
  document.getElementById('main-app').classList.add('hidden');
});

// Tab navigation
document.getElementById('view-tab').addEventListener('click', function (e) {
  e.preventDefault();
  // Hide all panes
  document.getElementById('view-pane').classList.remove('hidden');
  document.getElementById('issue-pane').classList.add('hidden');
  document.getElementById('verify-pane').classList.add('hidden');

  // Set active tab
  document.getElementById('view-tab').classList.add('active');
  document.getElementById('issue-tab').classList.remove('active');
  document.getElementById('verify-tab').classList.remove('active');

  app.loadCertificates();
});

document.getElementById('issue-tab').addEventListener('click', function (e) {
  e.preventDefault(); // This is important to prevent the default link behavior

  // Hide all panes
  document.getElementById('view-pane').classList.add('hidden');
  document.getElementById('issue-pane').classList.remove('hidden');
  document.getElementById('verify-pane').classList.add('hidden');

  // Set active tab
  document.getElementById('view-tab').classList.remove('active');
  document.getElementById('issue-tab').classList.add('active');
  document.getElementById('verify-tab').classList.remove('active');
});

document.getElementById('verify-tab').addEventListener('click', function (e) {
  e.preventDefault();
  // Hide all panes
  document.getElementById('view-pane').classList.add('hidden');
  document.getElementById('issue-pane').classList.add('hidden');
  document.getElementById('verify-pane').classList.remove('hidden');

  // Set active tab
  document.getElementById('view-tab').classList.remove('active');
  document.getElementById('issue-tab').classList.remove('active');
  document.getElementById('verify-tab').classList.add('active');
});

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', app.init);

// Initialize global functions for HTML access
window.selectOrg = selectOrg;
window.viewCertificateDetails = ui.showCertificateDetails;