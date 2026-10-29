function Test-ShowcaseHubReady {
    param($Hub)
    return ($null -ne $Hub -and $Hub.auth.port -eq 9299 -and $Hub.firestore.port -eq 9280)
}
