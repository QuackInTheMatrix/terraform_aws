document.addEventListener("DOMContentLoaded", () => {
    fetch('https://api.ivandeveric.site/api/db/fortunes')
        .then(response => response.json())
        .then(data => {
            document.getElementById("fortune").textContent=data.message
        })
        .catch(error => {
            console.error('Error fetching data:', error);
    });
    document.getElementById("fortune-button").addEventListener("click", () => {
        const fortuneInput = document.getElementById("fortune-input").value;
        const dataToAdd = { "message": fortuneInput };
        fetch('https://api.ivandeveric.site/api/db/fortunes', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(dataToAdd)
        })
        .then(response => response.json())
        .then(data => {
            document.getElementById("confirm-insert").textContent="Success!";
        })
        .catch(error => {
            document.getElementById("confirm-insert").textContent="Failure!";
            console.error('Error updating data:', error);
        });
    });
});
