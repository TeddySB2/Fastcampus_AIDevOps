package main

import (
	"slices"
	"testing"
)

func TestParseProductRowCategories(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want []string
	}{
		{"trim", " telescopes , accessories ", []string{"telescopes", "accessories"}},
		{"no_space", "telescopes,accessories", []string{"telescopes", "accessories"}},
		{"empty_item", "telescopes,,accessories", []string{"telescopes", "accessories"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p := parseProductRow("id", "name", "desc", "pic", "USD", tt.in, 1, 0)
			if got := p.GetCategories(); !slices.Equal(got, tt.want) {
				t.Errorf("categories = %q, want %q", got, tt.want)
			}
		})
	}
}
