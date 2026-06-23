const axios = require('axios');
async function main() {
  try {
    const res = await axios.get('http://localhost:5005/api/consignees?branch=MAIN');
    console.log(res.data);
  } catch (err) {
    console.error(err.response ? err.response.data : err.message);
  }
}
main();
