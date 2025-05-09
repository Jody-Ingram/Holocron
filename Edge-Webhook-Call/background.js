// Script: Edge-Webhook-Call.js
// Version: 1.0
// Date: 5/9/2025
// Author: Jody Ingram
// Notes: This is a plug-in for Microsoft Edge that is designed to send a selection of text to a specific webhook call. This can be used to generate tickets, etc. 

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "send-servicenow",
    title: "Send selection to ServiceNow",
    contexts: ["selection"]
  });
});

chrome.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId === "send-servicenow") {
    const payload = {
      short_description: info.selectionText,
      category: "inquiry"
    };
    fetch("https://WEBHOOK-URI-GOES-HERE", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Basic " + btoa("user:pass")
      },
      body: JSON.stringify(payload)
    })
    .then(r => r.json())
    .then(j => {
      chrome.notifications.create({
        type: "basic",
        iconUrl: "icon48.png",
        title: "Automation Ticket Created",
        message: `Incident ${j.result.number} created`
      });
    });
  }
});
