const gstin = '33AACCS1480M1ZA';

async function run() {
  try {
    const res = await fetch(`http://localhost:5005/api/gst-search/${gstin}`);
    const data = await res.json();
    console.log(JSON.stringify(data, null, 2));
  } catch(e) {
    console.log("Fetch failed:", e);
  }
}
run();
