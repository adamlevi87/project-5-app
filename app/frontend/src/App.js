import React, { useState } from 'react';

function App() {
  const [text, setText] = useState('');
  const [status, setStatus] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setStatus('Sending...');

    try {
      const res = await fetch(`${window.RUNTIME_CONFIG?.BACKEND_URL}/submit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text }),
      });

      if (!res.ok) throw new Error('Failed to submit');
      setStatus('Submitted successfully!');
    } catch (err) {
      console.error(err);
      setStatus('Error submitting text.');
    }
  };

  return (
    <div style={{ padding: '2rem' }}>
      <h1>Submit Text</h1>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Enter some text"
          style={{ width: '300px', marginRight: '1rem' }}
        />
        <button type="submit">Submit</button>
      </form>
      <p>{status}</p>
    </div>
  );
}

export default App;