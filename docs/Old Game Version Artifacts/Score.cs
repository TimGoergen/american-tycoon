using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using TMPro;
using System;

public class Score : MonoBehaviour
{
    [SerializeField] TextMeshProUGUI scoreDisplay;

    void Start() {
        ResetScore();
        EventManager.onBalanceChanged += UpdateScore;
    }

    private void ResetScore() {
        scoreDisplay.text = "0";
    }

    public void UpdateScore(float score) {
        scoreDisplay.text = score.ToString("#,0");
    }
}
