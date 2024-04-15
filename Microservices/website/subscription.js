// TODO: Implement subscription deactivation and merge to main
document.addEventListener("DOMContentLoaded", () => {
    let params = new URLSearchParams(document.location.search);
    let link = encodeURIComponent(params.get("activate"))
    if (link){
        fetch(`https://api.ivandeveric.site/fortune/subscribe`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({"activate":`${link}`})
        })
        .then(response => response.json())
        .then(data => {
            document.getElementById("subscription-status").textContent=data.message;
            document.getElementById("loader").remove();
            let redirect_link = document.createElement("a");
            redirect_link.href = "https://www.ivandeveric.site";
            redirect_link.innerHTML = "Click this link to go back to the website.";
            document.getElementById("seperator").parentNode.insertBefore(redirect_link, document.getElementById("seperator"));
        })
        .catch(error => {
            document.getElementById("subscription-status").textContent="The used link is invalid, please recheck.";
            console.error("Server error: ", error);
        });
    }else {
        link = encodeURIComponent(params.get("deactivate"))
        if(link){
            fetch(`https://api.ivandeveric.site/fortune/unsubscribe`, {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({"activate":`${link}`})
            })
            .then(response => response.json())
            .then(data => {
                document.getElementById("subscription-status").textContent=data.message;
                document.getElementById("loader").remove();
                let redirect_link = document.createElement("a");
                redirect_link.href = "https://www.ivandeveric.site";
                redirect_link.innerHTML = "Click this link to go back to the website.";
                document.getElementById("seperator").parentNode.insertBefore(redirect_link, document.getElementById("seperator"));
            })
            .catch(error => {
                document.getElementById("subscription-status").textContent="The used link is invalid, please recheck.";
                console.error("Server error: ", error);
            });
        }
    }
});

