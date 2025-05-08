// Fix script for certificate management UI issues

document.addEventListener('DOMContentLoaded', function () {
    console.log("Fix script loaded");

    // Fix 1: Handle tab navigation properly
    const viewTab = document.getElementById('view-tab');
    const issueTab = document.getElementById('issue-tab');
    const verifyTab = document.getElementById('verify-tab');

    const viewPane = document.getElementById('view-pane');
    const issuePane = document.getElementById('issue-pane');
    const verifyPane = document.getElementById('verify-pane');

    // Ensure we never follow href links in the tabs
    if (viewTab) viewTab.setAttribute('href', 'javascript:void(0)');
    if (issueTab) issueTab.setAttribute('href', 'javascript:void(0)');
    if (verifyTab) verifyTab.setAttribute('href', 'javascript:void(0)');

    // Fix tab navigation
    if (viewTab) {
        viewTab.addEventListener('click', function (e) {
            e.preventDefault();
            viewPane.classList.remove('hidden');
            issuePane.classList.add('hidden');
            verifyPane.classList.add('hidden');

            viewTab.classList.add('active');
            issueTab.classList.remove('active');
            verifyTab.classList.remove('active');

            // Load certificates
            try {
                app.loadCertificates();
            } catch (e) {
                console.error("Error loading certificates:", e);
            }
        });
    }

    if (issueTab) {
        issueTab.addEventListener('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            console.log("Issue tab clicked");

            viewPane.classList.add('hidden');
            issuePane.classList.remove('hidden');
            verifyPane.classList.add('hidden');

            viewTab.classList.remove('active');
            issueTab.classList.add('active');
            verifyTab.classList.remove('active');
        });
    }

    if (verifyTab) {
        verifyTab.addEventListener('click', function (e) {
            e.preventDefault();
            viewPane.classList.add('hidden');
            issuePane.classList.add('hidden');
            verifyPane.classList.remove('hidden');

            viewTab.classList.remove('active');
            issueTab.classList.remove('active');
            verifyTab.classList.add('active');
        });
    }

    // Fix for hiding revoke button for student organization
    function updateRevokeCertificateButtonVisibility() {
        const revokeCertBtn = document.getElementById('revoke-cert-btn');
        if (revokeCertBtn) {
            // Only show revoke button for University organization
            if (state.organization === 'student' || state.organization === 'verifier') {
                revokeCertBtn.style.display = 'none';
            } else {
                revokeCertBtn.style.display = 'block';
            }
        }
    }

    // Call when organization is selected
    const originalSelectOrg = window.selectOrg;
    if (typeof originalSelectOrg === 'function') {
        window.selectOrg = function (organization) {
            // Call the original function
            originalSelectOrg(organization);

            // Update revoke button visibility
            updateRevokeCertificateButtonVisibility();
        };
    }

    // Also check on page load and modal open
    document.getElementById('certificate-modal').addEventListener('show.bs.modal', function () {
        updateRevokeCertificateButtonVisibility();
    });

    // Check on page load
    if (typeof state !== 'undefined' && state.organization) {
        updateRevokeCertificateButtonVisibility();
    }

    // Fix 2: Ensure issue form is properly handled
    const issueForm = document.getElementById('issue-form');
    if (issueForm) {
        issueForm.addEventListener('submit', function (e) {
            e.preventDefault();
            e.stopPropagation();
            console.log("Form submission intercepted by fix script");

            const studentID = document.getElementById('student-id').value.trim();
            const certID = document.getElementById('cert-id').value.trim();
            const certHash = document.getElementById('cert-hash').value.trim();
            const issuer = document.getElementById('issuer').value.trim() || 'UniversityOrg';

            // Validation
            if (!studentID || !certID || !certHash) {
                alert("Please fill all required fields");
                return;
            }

            // Show a loading spinner on the button
            const submitBtn = document.getElementById('issue-cert-btn');
            const originalText = submitBtn.textContent;
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Processing...';

            // Make the API call
            fetch(`/api/${state.organization}/certificates`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-API-Key': state.apiKey
                },
                body: JSON.stringify({
                    studentID: studentID,
                    certID: certID,
                    certHash: certHash,
                    issuer: issuer
                })
            })
                .then(response => {
                    if (!response.ok) {
                        return response.json().then(data => {
                            throw new Error(data.error || 'Failed to issue certificate');
                        });
                    }
                    return response.json();
                })
                .then(data => {
                    // Clear the form
                    issueForm.reset();

                    // Show success message
                    const alertsContainer = document.getElementById('alerts-container');
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

                    // Reset button
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = originalText;

                    // Show the certificates tab with the new certificate
                    if (viewTab) viewTab.click();

                    // Force refresh certificates
                    try {
                        app.loadCertificates();
                    } catch (e) {
                        console.error("Error refreshing certificates:", e);
                        // Fallback reload
                        setTimeout(() => {
                            if (viewTab) viewTab.click();
                        }, 1000);
                    }
                })
                .catch(error => {
                    console.error("Error issuing certificate:", error);
                    alert(`Error: ${error.message || 'Failed to issue certificate'}`);

                    // Reset button
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = originalText;
                });
        });
    }

    // Fix 3: Ensure certificate viewing works
    document.addEventListener('click', function (e) {
        if (e.target && e.target.classList.contains('view-cert-btn')) {
            const certId = e.target.getAttribute('data-cert-id');
            if (certId) {
                console.log("View button clicked for certificate:", certId);

                // Show certificate details modal
                const modal = new bootstrap.Modal(document.getElementById('certificate-modal'));
                const modalBody = document.getElementById('certificate-modal-body');

                // Show loading state
                modalBody.innerHTML = `
                    <div class="text-center">
                        <div class="spinner-border" role="status">
                            <span class="visually-hidden">Loading...</span>
                        </div>
                    </div>
                `;

                modal.show();

                // Fetch certificate details
                fetch(`/api/${state.organization}/certificates/${certId}`, {
                    headers: {
                        'X-API-Key': state.apiKey
                    }
                })
                    .then(response => {
                        if (!response.ok) {
                            return response.json().then(data => {
                                throw new Error(data.error || 'Failed to load certificate');
                            });
                        }
                        return response.json();
                    })
                    .then(certificate => {
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

                        modalBody.innerHTML = detailsHtml;
                    })
                    .catch(error => {
                        console.error("Error loading certificate details:", error);
                        modalBody.innerHTML = `
                        <div class="alert alert-danger">
                            Failed to load certificate details: ${error.message}
                        </div>
                    `;
                    });
            }
        }
    });

    // Fix 4: Add verification form handling
    const verifyForm = document.getElementById('verify-form');
    if (verifyForm) {
        verifyForm.addEventListener('submit', function (e) {
            e.preventDefault();
            e.stopPropagation();
            console.log("Verify form submission intercepted");

            const certID = document.getElementById('verify-cert-id').value.trim();

            if (!certID) {
                alert("Please enter a Certificate ID to verify");
                return;
            }

            // Show loading state in verification result area
            const verificationResult = document.getElementById('verification-result');
            verificationResult.innerHTML = `
                <div class="text-center">
                    <div class="spinner-border" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <p>Verifying certificate...</p>
                </div>
            `;
            verificationResult.classList.remove('hidden');

            // Submit button loading state
            const submitBtn = verifyForm.querySelector('button[type="submit"]');
            const originalBtnText = submitBtn.textContent;
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Verifying...';

            // Make API call to verify certificate
            fetch(`/api/${state.organization}/certificates/verify/${certID}`, {
                headers: {
                    'X-API-Key': state.apiKey
                }
            })
                .then(response => {
                    if (!response.ok) {
                        return response.json().then(data => {
                            throw new Error(data.error || 'Failed to verify certificate');
                        });
                    }
                    return response.json();
                })
                .then(result => {
                    // Check verification result
                    const isValid = result.valid === true || (typeof result.valid === 'string' && result.valid.toLowerCase() === 'true');

                    // Display verification result
                    verificationResult.innerHTML = `
                    <div class="alert ${isValid ? 'alert-success' : 'alert-danger'}">
                        <strong>${isValid ? 'Certificate is valid!' : 'Certificate verification failed!'}</strong><br>
                        The blockchain confirms this certificate ${isValid ? 'is authentic' : 'has issues or does not exist'}.
                    </div>
                `;

                    // Add notification
                    const alertsContainer = document.getElementById('alerts-container');
                    const alertId = `alert-${Date.now()}`;
                    alertsContainer.innerHTML = `
                    <div id="${alertId}" class="alert alert-${isValid ? 'success' : 'danger'} alert-dismissible fade show" role="alert">
                        Certificate verification ${isValid ? 'successful!' : 'failed!'}
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

                    // Reset button
                    submitBtn.disabled = false;
                    submitBtn.textContent = originalBtnText;
                })
                .catch(error => {
                    console.error("Error verifying certificate:", error);

                    // Show error in verification result
                    verificationResult.innerHTML = `
                    <div class="alert alert-danger">
                        <strong>Verification failed:</strong> ${error.message || 'Unable to verify certificate'}
                    </div>
                `;

                    // Reset button
                    submitBtn.disabled = false;
                    submitBtn.textContent = originalBtnText;
                });
        });
    }

    // Fix 5: Add revoke certificate functionality
    const revokeCertBtn = document.getElementById('revoke-cert-btn');
    if (revokeCertBtn) {
        revokeCertBtn.addEventListener('click', function (e) {
            e.preventDefault();
            console.log("Revoke button clicked");

            // Get the current certificate ID from state
            const certID = state.currentCertificateId;

            if (!certID) {
                console.error("No certificate ID found for revocation");
                return;
            }

            // Confirm before revoking
            if (!confirm(`Are you sure you want to revoke certificate ${certID}?`)) {
                return;
            }

            // Show loading state
            revokeCertBtn.disabled = true;
            const originalText = revokeCertBtn.textContent;
            revokeCertBtn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Revoking...';

            // Call the API to revoke the certificate
            fetch(`/api/${state.organization}/certificates/${certID}`, {
                method: 'DELETE',
                headers: {
                    'X-API-Key': state.apiKey
                }
            })
                .then(response => {
                    if (!response.ok) {
                        return response.json().then(data => {
                            throw new Error(data.error || 'Failed to revoke certificate');
                        });
                    }
                    return response.json();
                })
                .then(data => {
                    console.log("Certificate revoked successfully:", data);

                    // Hide the modal
                    const modal = bootstrap.Modal.getInstance(document.getElementById('certificate-modal'));
                    if (modal) {
                        modal.hide();
                    }

                    // Show success notification
                    const alertsContainer = document.getElementById('alerts-container');
                    const alertId = `alert-${Date.now()}`;
                    alertsContainer.innerHTML = `
                    <div id="${alertId}" class="alert alert-success alert-dismissible fade show" role="alert">
                        Certificate ${certID} revoked successfully!
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

                    // Refresh the certificate list
                    try {
                        app.loadCertificates();
                    } catch (e) {
                        console.error("Error refreshing certificates:", e);
                        // Navigate back to view tab and force reload
                        const viewTab = document.getElementById('view-tab');
                        if (viewTab) viewTab.click();
                    }
                })
                .catch(error => {
                    console.error("Error revoking certificate:", error);
                    alert(`Error: ${error.message || 'Failed to revoke certificate'}`);

                    // Reset button state
                    revokeCertBtn.disabled = false;
                    revokeCertBtn.textContent = originalText;
                });
        });
    }

    // Handle verifier organization error with a specific UI
    function handleOrg3Integration() {
        // State management for the current organization
        if (typeof state === 'undefined' || !state.organization) {
            console.log("Waiting for application state to be initialized");
            return;
        }

        // Only handle verifier-specific logic
        if (state.organization !== 'verifier') {
            return;
        }

        console.log("Processing verifier organization logic");

        // Add a loading indicator to the certificates container
        const certificatesContainer = document.getElementById('certificates-container');
        if (certificatesContainer) {
            certificatesContainer.innerHTML = `
                <div class="text-center p-5">
                    <div class="spinner-border text-primary mb-3" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <p>Loading verifier certificates...</p>
                </div>
            `;
        }

        // Fetch certificates with proper error handling
        fetch(`/api/${state.organization}/certificates`, {
            headers: {
                'X-API-Key': state.apiKey
            }
        })
            .then(response => {
                if (!response.ok) {
                    return response.json().then(data => {
                        throw new Error(JSON.stringify(data));
                    });
                }
                return response.json();
            })
            .then(certificates => {
                // Handle normal certificate display through the app's existing function
                if (typeof app !== 'undefined' && typeof app.displayCertificates === 'function') {
                    app.displayCertificates(certificates);
                } else {
                    console.error("Application not properly initialized, can't display certificates");
                }
            })
            .catch(error => {
                console.error("Error loading verifier certificates:", error);

                let errorData;
                try {
                    // Try to parse the error data
                    errorData = JSON.parse(error.message);
                } catch (e) {
                    // If not parseable, just use a generic message
                    errorData = {
                        error: "Connection Error",
                        message: "The Verifier organization is not available.",
                        setup_instructions: "Please ensure Org3 has been added to the network."
                    };
                }

                // Show the error in the certificates container
                if (certificatesContainer) {
                    certificatesContainer.innerHTML = `
                    <div class="alert alert-warning">
                        <h4 class="alert-heading">${errorData.error || "Organization Not Available"}</h4>
                        <p>${errorData.message || "The Verifier organization could not be connected."}</p>
                        <hr>
                        <p class="mb-0"><strong>Setup Instructions:</strong> ${errorData.setup_instructions || "Please contact your administrator."}</p>
                        
                        <div class="mt-3">
                            <button class="btn btn-primary" onclick="window.location.reload()">Retry Connection</button>
                        </div>
                    </div>
                `;
                }
            });
    }

    // Monitor for login state changes
    const originalSetItem = localStorage.setItem;
    localStorage.setItem = function (key, value) {
        originalSetItem.call(this, key, value);

        // If login state changes, check if we need to handle Org3
        if (key === 'certificateAppState') {
            try {
                const newState = JSON.parse(value);
                if (newState.organization === 'verifier') {
                    setTimeout(handleOrg3Integration, 500); // Small delay to ensure DOM is updated
                }
            } catch (e) {
                console.error("Error parsing app state:", e);
            }
        }
    };

    // If we're already logged in as verifier, handle it
    try {
        const savedState = localStorage.getItem('certificateAppState');
        if (savedState) {
            const parsedState = JSON.parse(savedState);
            if (parsedState.organization === 'verifier') {
                setTimeout(handleOrg3Integration, 500);
            }
        }
    } catch (e) {
        console.error("Error checking saved state:", e);
    }

    console.log("Verifier organization error handling initialized");

    console.log("Fix script initialization complete");
});