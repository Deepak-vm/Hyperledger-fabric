const { executePeerQuery } = require('./cli-helper');

async function testQuery() {
  try {
    console.log("Testing GetAllCertificates query using CLI...")
    const result = await executePeerQuery('GetAllCertificates', []);
    console.log("Results:", result);
    
    console.log("\nTesting GetCertificate for cert003...")
    const cert = await executePeerQuery('GetCertificate', ['cert003']);
    console.log("Certificate:", cert);
  } catch (error) {
    console.error("Error:", error);
  }
}

testQuery();
